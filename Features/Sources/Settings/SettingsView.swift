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

extension Tab {

  init(_ value: Value, @ViewBuilder content: () -> Content) where Value == Settings.TabId, Label == DefaultTabLabel, Content: View {
    self.init(value.title, systemImage: value.systemImage, value: value, content: content)
  }
}

public struct SettingsView: View {
  @Bindable private var store: StoreOf<Settings>
  @State private var changingKeyWidth: Bool = false
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
//    NavigationStack(path: $store.scope(state: \.path, action: \.path)) {
    TabView(selection: $store.activeTab) {
      Tab(.presets) {
        presetsSection
      }
      Tab(.fonts) {
        fontsSection
      }
      if isApp {
        Tab(.keys) {
          keyboardSection
        }
        if store.hasMIDI {
          Tab(.midi) {
            midiSection
          }
        }
      }
      Tab(.tuning) {
        tuningSection
      }
      if isApp {
        Tab(.app) {
          appSection
        }
      }
      Tab(.about) {
        aboutSection
      }
    }
//      .font(.settings)
//      .formStyle(.grouped)
//      .circledCheckMarkToggleStyle()
//      .navigationTitle("Settings")
//      .toolbar {
//        ToolbarItem(placement: .automatic) {
//          Button {
//            store.send(.dismissButtonTapped, animation: .default)
//          } label: {
//            Image(systemName: .saveButtonImageName)
//          }
//        }
//      }
//      .animation(.smooth, value: changingKeyWidth)
//    } destination: { store in
//      switch store.case {
//      case .midiAssignments(let store): MIDIAssignmentsView(store: store)
//      case .midiConnections(let store): MIDIConnectionsView(store: store)
//      case .midiControllers(let store): MIDIControllersView(store: store)
//      }
//    }
    .alert($store.scope(state: \.destination?.alert, action: \.destination.alert))
    .filePicker($store.scope(state: \.destination?.backupPicker, action: \.destination.backupPicker))
    .task {
      await store.send(.initialize).finish()
    }
    .useColorScheme() // TODO: find better approach for updating colorScheme when colorSchemeBehavior changes
  }
}

extension SettingsView {

  private func toggleInfo(_ name: LocalizedStringKey, _ description: () -> LocalizedStringKey) -> some View {
    VStack(alignment: .leading, spacing: 8) {
      Text(name)
      Text(description())
      .font(.settingsDescription)
    }
  }

  private var presetsSection: some View {
    Form {
      Toggle(
        isOn: Binding(
          get: { store.favoritesOnTop },
          set: { newValue in store.$favoritesOnTop.withLock { $0 = newValue } }
        )
      ) {
        toggleInfo("Favorites on top") {
"""
When enabled, favorites appear before presets. Otherwise, they appear after the preset they originated from.
"""
        }
      }
      Toggle(
        isOn: Binding(
          get: { store.showOnlyFavorites },
          set: { newValue in store.$showOnlyFavorites.withLock { $0 = newValue } }
        )
      ) {
        toggleInfo("Show only favorites") {
"""
When enabled, only favorites will appear in the preset list.
"""
        }
      }
      Toggle(
        isOn: Binding(
          get: {
            store.starFavoriteNames
          },
          set: { newValue in
            store.$starFavoriteNames.withLock { $0 = newValue }
          }
        )
      ) {
        toggleInfo("Show \(Image(systemName: store.favoriteSymbolName)) in favorites") {
"""
When enabled, prefix favorite names with a \(Image(systemName: store.favoriteSymbolName)).
"""
        }
      }
      Toggle(
        isOn: Binding(
          get: { store.sortPresetsByName },
          set: { newValue in
            store.$sortPresetsByName.withLock { $0 = newValue }
          }
        )
      ) {
        toggleInfo("Sort presets by name") {
"""
When enabled, order presets by their name. Otherwise, order them by their index in the soundfont file.
"""
        }
      }
      Toggle(
        isOn: Binding(
          get: { store.playSoundOnPresetChange },
          set: { newValue in store.$playSoundOnPresetChange.withLock { $0 = newValue } }
        ),
      ) {
        toggleInfo("Play sound on preset change") {
"""
When enabled, changing a preset will play a short note in the synthesizer using the new preset.
"""
        }
      }
      Toggle(
        isOn: Binding(
          get: { store.showPresetIndexView },
          set: { newValue in store.$showPresetIndexView.withLock { $0 = newValue } }
        )
      ) {
        toggleInfo("Show preset index strip") {
"""
When enabled, overlay the presets list with a compact list of section indices for quick access to a section.
"""
        }
      }
    }
  }

  private var keyboardSection: some View {
    Form {
      VStack(alignment: .leading) {
        HStack {
          Text("Key labels")
          Spacer()
          Picker(
            selection: Binding(
              get: { store.keyLabels },
              set: { newValue in store.$keyLabels.withLock { $0 = newValue } }
            )
          ) {
            ForEach(KeyLabels.allCases) { kind in
              Text(kind.rawValue)
            }
          } label: {
            Text("Key Labels")
          }
          .pickerStyle(.segmented)
        }
        Text("Controls what keys will have a MIDI note label on them.")
          .font(.settingsDescription)
      }
      Toggle(
        isOn: Binding(
          get: { store.showKeyNotes },
          set: { newValue in store.$showKeyNotes.withLock { $0 = newValue } }
        )
      ) {
        toggleInfo("Show key note in toolbar") {
"""
The MIDI note label will briefly appear in the toolbar when a key is touched.
"""
        }
      }
      Toggle(
        isOn: Binding(
          get: { store.showSolfegeTags },
          set: { newValue in store.$showSolfegeTags.withLock { $0 = newValue } }
        )
      ) {
        toggleInfo("Show solfège tag in toolbar") {
          """
The solfège tag for a note will briefly appear in the toolbar when a key is touched.
"""
        }
      }
      Toggle(
        isOn: Binding(
          get: { store.keyboardSlides },
          set: { newValue in store.$keyboardSlides.withLock { $0 = newValue } }
        )
      ) {
        toggleInfo("Keyboard slides with touch") {
"""
When enabled, the keyboard will slide with the movement of a key touch. Otherwise, it will remain fixed \
and key touch movements will trigger neighboring keys.
Controlled by the \(Image(systemName: .fixedKeyboardButtonImageName)) button in the toolbar.
"""
        }
      }
      VStack {
        Text("Key Width")
        Slider(
          value: Binding(
            get: { store.keyWidth },
            set: { newValue in store.keyWidth = newValue }
          ),
          in: 32...96, step: 1
        ) {
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
    NavigationStack(path: $store.scope(state: \.path, action: \.path)) {
      Form {
        VStack(alignment: .leading, spacing: 8) {
          HStack {
            Text("Channel")
            Spacer()
            Text(store.midiChannel == -1 ? "Any" : "\(store.midiChannel + 1)")
            Spacer()
            Stepper(
              "",
              value: Binding(
                get: { store.midiChannel },
                set: { newValue in store.$midiChannel.withLock { $0 = newValue } }
              ),
              in: -1...15
            )
            .labelsHidden()
          }
          Text(
            store.midiChannel == -1
            ? """
Process any traffic regardless of MIDI channel.
Change to limit traffic to a specific channel.
"""
            : """
Only process traffic on MIDI channel \(store.midiChannel + 1).
Adjust to change channel or decrement completely to allow any channel traffic.
"""
          )
          .font(.settingsDescription)
        }
        .animation(.smooth, value: store.midiChannel)
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
        .alignmentGuide(.listRowSeparatorLeading) { _ in 0 }
        Toggle(
          isOn: Binding(
            get: { store.midiAutoConnect },
            set: { newValue in store.$midiAutoConnect.withLock { $0 = newValue } }
          )
        ) {
          toggleInfo("New devices will auto-connect") {
"""
When enabled, new unknown devices will auto-connect to the synthesizer. Otherwise, you must connect the \
device using the button above.
"""
          }
        }
        Toggle(
          isOn: Binding(
            get: { store.showMIDITrafficIndicator },
            set: { newValue in store.$showMIDITrafficIndicator.withLock { $0 = newValue } }
          )
        ) {
          toggleInfo("Show MIDI activity indicator in toolbar") {
"""
When enabled, the toolbar will indicate MIDI traffic by flashing small circle. Accepted traffic will flash green and \
ignored traffic will flash amber.
"""
          }
        }
        Toggle(
          isOn: Binding(
            get: { store.showMIDINotesOnKeyboard },
            set: { newValue in store.$showMIDINotesOnKeyboard.withLock { $0 = newValue } }
          )
        ) {
          toggleInfo("Show MIDI note activity on keyboard") {
"""
When enabled, the virtual keyboard will highlight MIDI note activity that corresponds to the keyboard keys. \
The keys will normally flash green, but they will flash red if the volume of the device is muted or there is no \
active preset.
"""
          }
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
        VStack(alignment: .leading) {
          HStack {
            Text("Pitch bend range (semitones)")
            Spacer()
            Text("\(store.pitchBendRange)")
            Spacer()
            Stepper(
              "",
              value: Binding(
                get: { store.pitchBendRange },
                set: { newValue in store.$pitchBendRange.withLock { $0 = newValue } }
              ),
              in: 1...24
            )
            .labelsHidden()
          }
          Text(
"""
Configures the range of the pitch wheel messages received by the synthesizer. Default is 2 semtones but it can be as much \
as 2 octaves (24 semitones).
"""
          )
          .font(.settingsDescription)
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
    } destination: { store in
      switch store.case {
      case .midiAssignments(let store): MIDIAssignmentsView(store: store)
      case .midiConnections(let store): MIDIConnectionsView(store: store)
      case .midiControllers(let store): MIDIControllersView(store: store)
      }
    }
  }

  private var tuningSection: some View {
    Form {
      TuningView(store: store.scope(state: \.tuning, action: \.tuning))
    }
  }

  private var fontsSection: some View {
    Form {
      Group {
        if isApp {
          Toggle(
            isOn: Binding(
              get: { store.copyFileWhenInstalling },
              set: { newValue in store.copyFileWhenInstalling = newValue }
            )
          ) {
            toggleInfo("Copy SF2 files to app folder on device when adding") {
"""
Enabled is the safest option but files consume space on your device. \
Disable to link directly to files in iCloud or on external drives.
"""
            }
          }
        }
        Toggle(
          isOn: Binding(
            get: { store.hideEmptyTags },
            set: { newValue in store.$hideEmptyTags.withLock { $0 = newValue  } }
          )
        ) {
          toggleInfo("Hide tags with no sound fonts") {
"""
Enable to reduce clutter in the main tags view. Your tags will always appear regardless of content.
"""
          }
        }
        Toggle(
          isOn: Binding(
            get: { store.hideBuiltinFonts },
            set: { newValue in store.$hideBuiltinFonts.withLock { $0 = newValue  } }
          )
        ) {
          toggleInfo("Hide built-in SF2 files") {
"""
Do not show the pre-installed sound fonts when the "All" tag is active.
"""
          }
        }
      }
    }
  }

  private var appSection: some View {
    Form {
      Group {
        VStack(alignment: .leading, spacing: 8) {
          HStack {
            Text("Color scheme")
            Spacer()
            Picker(
              selection: Binding(
                get: { store.colorSchemeBehavior },
                set: { newValue in store.$colorSchemeBehavior.withLock { $0 = newValue  } }
              )
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
        Toggle(
          isOn: Binding(
            get: { store.showActiveVoiceCount },
            set: { newValue in store.$showActiveVoiceCount.withLock { $0 = newValue } }
          )
        ) {
          toggleInfo("Show active voice counter") {
"""
When active, show in the toolbar the number of voices playing in the synthesizer.
"""
          }
        }
        if isApp {
#if os(iOS)
          Toggle(
            isOn: Binding(
              get: { store.mixWithOtherApps },
              set: { newValue in store.$mixWithOtherApps.withLock { $0 = newValue } }
            )
          ) {
            toggleInfo("Mix audio with other apps on device") {
"""
When enabled, the synthesizer audio output is mixed with other audio output generated on the device. Otherwise, you will \
only hear the synthesizer output.
"""
            }
          }
          .onChange(of: store.mixWithOtherApps) {
            _ = audioSession.restart()
          }
          Toggle(
            isOn: Binding(
              get: { store.duckOtherApps },
              set: { newValue in store.$duckOtherApps.withLock { $0 = newValue } }
            )
          ) {
            toggleInfo("Reduce audio from other apps") {
"""
When enabled, the audio from other apps will be reduced before being mixed with the synthesizer output.
"""
            }
          }
          .disabled(store.mixWithOtherApps == false)
          .onChange(of: store.duckOtherApps) {
            _ = audioSession.restart()
          }
          Toggle(
            isOn: Binding(
              get: { store.backgroundProcessing },
              set: { newValue in store.$backgroundProcessing.withLock { $0 = newValue } }
          )
          ) {
            toggleInfo("Background processing mode") {
"""
When enabled, the application will continueto process MIDI messages while the app is not active.
"""
            }
          }
#endif // os(iOS)
          Toggle(
            isOn: Binding(
              get: { store.disableIdleTimer },
              set: { newValue in store.disableIdleTimer = newValue }
            )
          ) {
            toggleInfo("Disable device locking while active") {
"""
Controls whether the device will stay open and unlocked as long as the app is active. This can increase the drain on the \
battery.
"""
            }
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
        }
      }
    }
  }

  private var aboutSection: some View {
    Form {
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
              Image(systemName: .emailButtonImageName)
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
  // swiftlint:disable:next redundant_discardable_let
  let _ = prepareDependencies {
    $0.defaultDatabase = previewDatabase()
  }
  SettingsView.preview
}

#endif // DEBUG
