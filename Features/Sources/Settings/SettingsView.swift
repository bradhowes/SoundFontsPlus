import Dependencies
import FeatureSupport
import Keyboard
import MIDIAssignments
import MIDIConnections
import MIDIControllers
import MIDITrafficIndicator
import MorkAndMIDI
import Sharing
import SwiftUI
import Tuning

public struct SettingsView: View {
  @Bindable private var store: StoreOf<Settings>
  @State private var changingKeyWidth: Bool = false
  @Shared(.backupRestoreEnabled) private var backupRestoreEnabled
  @Dependency(\.audioSession) private var audioSession
  @Dependency(\.fileManager) private var fileManager

  private let isAUv3: Bool
  private var isApp: Bool { !isAUv3 }
  private let showFakeKeyboard: Bool
  private let bundle = Bundle.main

  public init(store: StoreOf<Settings>, showFakeKeyboard: Bool, isAUv3: Bool) {
    self.store = store
    self.showFakeKeyboard = showFakeKeyboard
    self.isAUv3 = isAUv3
  }

  public var body: some View {
    NavigationStack(path: $store.scope(state: \.path, action: \.path)) {
      Form {
        presetsSection
        if !isAUv3 {
          if isApp {
            keyboardSection
            if store.hasMIDI {
              midiSection
            }
          }
        }
        tuningSection
        fontsSection
        if isApp {
          appSection
        }
        aboutSection
      }
      .font(.settings)
      .formStyle(.grouped)
      .circledCheckMarkToggleStyle()
      .navigationTitle("Settings")
      .toolbar {
        ToolbarItem(placement: .automatic) {
          Button("Done") { store.send(.dismissButtonTapped, animation: .default) }
            .font(.button)
        }
      }
      .animation(.smooth, value: changingKeyWidth)
    } destination: { store in
      switch store.case {
      case .midiAssignments(let store): MIDIAssignmentsView(store: store)
      case .midiConnections(let store): MIDIConnectionsView(store: store)
      case .midiControllers(let store): MIDIControllersView(store: store)
      }
    }
    .alert($store.scope(state: \.destination?.alert, action: \.destination.alert))
    .filePicker($store.scope(state: \.destination?.backupPicker, action: \.destination.backupPicker))
    .task {
      await store.send(.initialize).finish()
    }
    .darkMode() // TODO: find better approach for updating colorScheme when colorSchemeBehavior changes
  }
}

extension SettingsView {

  private var presetsSection: some View {
    Section("Presets") {
      Toggle(isOn: $store.favoritesOnTop) {
        Text("Favorites on top")
      }
      Toggle(isOn: $store.showOnlyFavorites) {
        Text("Show only favorites")
      }
      Toggle(isOn: $store.starFavoriteNames) {
        HStack {
          Text("Show")
          Image(systemName: store.favoriteSymbolName)
          Text("in favorites")
        }
      }
      Toggle(isOn: $store.sortPresetsByName) {
        Text("Presets sorted by name")
      }
      Toggle(isOn: $store.playSoundOnPresetChange) {
        Text("Play sound on preset change")
      }
    }
  }

  private var keyboardSection: some View {
    Section("Keyboard") {
      HStack {
        Text("Key labels")
        Spacer()
        Picker(
          selection: $store.keyLabels
        ) {
          ForEach(KeyLabels.allCases) { kind in
            Text(kind.rawValue)
          }
        } label: {
          Text("Key Labels")
        }
        .pickerStyle(.segmented)
      }
      Toggle(isOn: $store.showKeyNotes) {
        Text("Show key note in toolbar")
      }
      Toggle(isOn: $store.showSolfegeTags) {
        Text("Show solfège tag in toolbar")
      }
      Toggle(isOn: $store.keyboardSlides) {
        Text("Keyboard slides with touch")
      }
      VStack {
        Text("Key Width")
        Slider(value: $store.keyWidth, in: 32...96, step: 1) {
          Text("Key Width")
        } onEditingChanged: { editing in
          changingKeyWidth = editing
        }
      }
      if showFakeKeyboard && changingKeyWidth {
        KeyboardView(store: Store(initialState: .init(settingsDemo: true)) { Keyboard() })
          .transition(.opacity)
      }
    }
  }

  private var midiSection: some View {
    Section("MIDI") {
      VStack(alignment: .leading, spacing: 8) {
        HStack {
          Text("Channel")
          Spacer()
          Text(store.midiChannel == -1 ? "Any" : "\(store.midiChannel + 1)")
          Spacer()
          Stepper("", value: $store.midiChannel, in: -1...15)
            .labelsHidden()
        }
        Text(
          store.midiChannel == -1
          ? "Process any traffic regardless of MIDI channel."
          : "Only process traffic on MIDI channel \(store.midiChannel + 1)."
        )
        .font(.settingsDescription)
      }
      HStack {
        Spacer()
        MIDITrafficIndicatorView(store: store.scope(state: \.midiTrafficIndicator, action: \.midiTrafficIndicator))
        Button {
          store.send(.midiConnectionsButtonTapped)
        } label: {
          Text("^[\(store.midiDevicesCount) device](inflect: true) / ^[\(store.midiConnectedCount) connected](inflect: true)")
        }
        Spacer()
      }
      Toggle(isOn: $store.midiAutoConnect) {
        Text("New devices will auto-connect")
      }
      Toggle(isOn: $store.showMIDITrafficIndicator) {
        Text("Show MIDI activity indicator in toolbar")
      }
      Toggle(isOn: $store.showMIDINotesOnKeyboard) {
        Text("Show MIDI note activity on keyboard")
      }
      HStack {
        Text("Bluetooth MIDI")
        Spacer()
        Button {
          store.send(.bluetoothMIDILocateButtonTapped)
        } label: {
          Text("Locate")
        }
      }
      HStack {
        Text("Pitch bend range (semitones)")
        Spacer()
        Text("\(store.pitchBendRange)")
        Spacer()
        Stepper("", value: $store.pitchBendRange, in: 1...24)
          .labelsHidden()
      }
      HStack {
        Spacer()
        Button {
          store.send(.midiControllersButtonTapped)
        } label: {
          Text("MIDI Controllers")
        }
        Spacer()
        Button {
          store.send(.midiAssignmentsButtonTapped)
        } label: {
          Text("MIDI Assignments")
        }
        Spacer()
      }
      .buttonStyle(.borderless) // !!! keep from activating entire row and *both* buttons when one is touched
    }
    .alignmentGuide(.listRowSeparatorLeading) { _ in 0 }
  }

  private var tuningSection: some View {
    TuningView(store: store.scope(state: \.tuning, action: \.tuning))
  }

  private var fontsSection: some View {
    Section("Fonts") {
      Group {
        if isApp {
          Toggle(isOn: $store.copyFileWhenInstalling) {
            VStack(alignment: .leading, spacing: 8) {
              Text("Copy SF2 files to app folder on device when adding")
              Text(
"""
Enabled is the safest option but files consume space on your device. \
Disable to link directly to files in iCloud or on external drives.
"""
              )
              .font(.settingsDescription)
            }
          }
        }
        Toggle(isOn: $store.hideEmptyTags) {
          VStack(alignment: .leading, spacing: 8) {
            Text("Hide tags with no sound fonts")
            Text(
"""
Enable to reduce clutter in the main tags view. Tag editors will always show all tags.
"""
            )
            .font(.settingsDescription)
          }
        }
        Toggle(isOn: $store.hideBuiltinFonts) {
          VStack(alignment: .leading, spacing: 8) {
            Text("Hide built-in SF2 files")
            Text(
"""
Do not show the pre-installed sound fonts when the "All" tag is active.
"""
            )
            .font(.settingsDescription)
          }
        }
      }
    }
  }

  private var appSection: some View {
    Section("Application") {
      Group {
        VStack(alignment: .leading, spacing: 8) {
          HStack {
            Text("Color scheme")
            Spacer()
            Picker(
              selection: $store.colorSchemeBehavior
            ) {
              ForEach(ColorSchemeBehavior.allCases) { kind in
                Text(kind.rawValue)
              }
            } label: {
              Text("")
            }
            .pickerStyle(.segmented)
          }
          Text(
"""
The color scheme can track the device's setting, or it can be fixed to a constant scheme.
"""
          )
          .font(.settingsDescription)
        }
        Toggle(isOn: $store.showActiveVoiceCount) {
          Text("Show active voice counter")
        }
        if isApp {
#if os(iOS)
          Toggle(isOn: $store.mixWithOtherApps) {
            Text("Mix audio with other apps on device")
          }
          .onChange(of: store.mixWithOtherApps) {
            _ = audioSession.restart()
          }
          Toggle(isOn: $store.duckOtherApps) {
            Text("Reduce audio from other apps")
          }
          .disabled(store.mixWithOtherApps == false)
          .onChange(of: store.duckOtherApps) {
            _ = audioSession.restart()
          }
          Toggle(isOn: $store.backgroundProcessing) {
            Text("Background processing mode")
          }
#endif
          Toggle(isOn: $store.disableIdleTimer) {
            Text("Disable device locking while active")
          }
          HStack {
            VStack(alignment: .leading, spacing: 8) {
              Text("Restore to initial install")
              Text(
"""
Removes all installed SF2 files and any customizations — same as reinstalling application.
"""
              )
              .font(.settingsDescription)
            }
            Spacer()
            Button {
              store.send(.delegate(.reinitialize))
            } label: {
              Text("Reinitialize")
            }
          }
          if backupRestoreEnabled {
            HStack {
              VStack(alignment: .leading, spacing: 8) {
                Text("Create backup of database and SF2 files")
                Text(
"""
Backups are stored in the SoundFonts+ iCloud folder. Sound font files that were copied onto device are also backed up.
"""
                )
                .font(.settingsDescription)
              }
              Spacer()
              Button {
                store.send(.createBackupTapped)
              } label: {
                Text("Backup")
              }
            }
            .disabled(fileManager.cloudDocumentsDirectory() == nil)
            HStack {
              VStack(alignment: .leading, spacing: 8) {
                Text("Restore from backup")
                Text(
"""
Erases current database and SF2 files with contents of previous backup.
"""
                )
                .font(.settingsDescription)
              }
              Spacer()
              Button {
                store.send(.restoreBackupTapped)
              } label: {
                Text("Restore")
              }
            }
            .disabled(fileManager.cloudDocumentsDirectory() == nil)
          }
        }
      }
    }
  }

  private var aboutSection: some View {
    Section("About") {
      Group {
        if isApp {
          HStack {
            Text("View change history")
            Spacer()
            Button {
              store.send(.delegate(.showChanges))
            } label: {
              Text("Changes")
            }
          }
          HStack {
            Text("View tutorial screens")
            Spacer()
            Button {
              store.send(.delegate(.showTutorial))
            } label: {
              Text("Tutorial")
            }
          }
        }
        HStack {
          Text("Version \(bundle.releaseVersionNumber)")
          Spacer()
          if isApp {
            Button {
              store.send(.reviewAppTapped)
            } label: {
              Text("Review App")
            }
          }
        }
        if isApp {
          HStack {
            Text("Contact developer (bradhowes@mac.com)")
            Spacer()
            Button {
              store.send(.contactDeveloperTapped)
            } label: {
              Image(systemName: "paperplane")
            }
          }
        }
      }
    }
  }
}

extension View {

  public func settingsSheet(_ store: Binding<StoreOf<Settings>?>, showFakeKeyboard: Bool, isAUv3: Bool) -> some View {
    self
      .sheet(item: store) {
        SettingsView(store: $0, showFakeKeyboard: showFakeKeyboard, isAUv3: isAUv3)
      }
  }
}

#if DEBUG

extension SettingsView {
  static var preview: some View {
    @Shared(.midi) var midi = MIDI(clientName: "Test", uniqueId: 123, midiProto: .v1_0)
    midi?.start()
    navigationBarTitleStyle()
    return VStack {
      SettingsView(
        store: Store(initialState: .init()) {
          Settings()
        },
        showFakeKeyboard: false,
        isAUv3: false
      )
    }
  }
}

#Preview {
  SettingsView.preview
}

#endif // DEBUG
