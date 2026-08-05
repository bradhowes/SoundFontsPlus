// Copyright © 2025 Brad Howes. All rights reserved.

public import AVFoundation
public import CasePaths
public import ComposableArchitecture
import Engine
import FeatureSupport
public import Models
import SQLiteData
import StructuredQueries
public import SwiftUI
public import Tuning

private let log: Logger = .init(category: "PresetEditor")

@Reducer
public struct PresetEditor {

  @Reducer
  public enum Destination {
    case alert(AlertState<Alert>)

    @CasePathable
    public enum Alert {
      case hidePresetConfirmed
    }
  }

  @ObservableState
  public struct State: Equatable {
    @Presents public var destination: Destination.State?

    public let sectionId: PresetsListSection.State.ID
    public let preset: Preset
    public let isActive: Bool
    public var displayName: String
    public var visible: Bool

    public let soundFontName: String
    public let originalAudioConfig: AudioConfig.Draft
    public var pendingAudioConfig: AudioConfig.Draft

    public var originalName: String
    public var notes: String

    public var gainSlider: Double
    public var panSlider: Double
    public var tuning: Tuning.State

    public var isFavorite: Bool { preset.kind == .favorite }

    public let audioUnit: AUAudioUnit?

    public init(sectionId: PresetsListSection.State.ID, preset: Preset, isActive: Bool, audioUnit: AUAudioUnit? = nil) {
      self.sectionId = sectionId
      self.preset = preset
      self.isActive = isActive
      self.displayName = preset.displayName
      self.originalName = preset.originalName
      self.visible = preset.kind == .preset
      self.notes = preset.notes
      self.soundFontName = preset.soundFontName

      let audioConfig = preset.audioConfigDraft
      self.originalAudioConfig = audioConfig
      self.pendingAudioConfig = audioConfig

      self.tuning = .init(frequency: audioConfig.customTuning, enabled: audioConfig.customTuningEnabled)

      self.gainSlider = audioConfig.gain
      self.panSlider = audioConfig.pan

      self.audioUnit = audioUnit
    }

    public mutating func save() {
      displayName = displayName.trimmed(or: preset.displayName)
      notes = notes.trimmed(or: preset.notes)

      pendingAudioConfig.gain = gainSlider
      pendingAudioConfig.pan = panSlider

      tuning.updateConfig(&pendingAudioConfig)

      withDatabaseWriter { db in
        try Preset.update {
          $0.displayName = displayName
          $0.notes = notes
          if !isFavorite {
            $0.kind = #bind(visible ? .preset : .hidden)
          }
        }
        .where { $0.id.eq(preset.id) }
        .execute(db)

        if pendingAudioConfig != originalAudioConfig {
          try AudioConfig.upsert {
            pendingAudioConfig
          }
          .execute(db)
        }
      }
    }
  }

  public enum Action: BindableAction {
    case binding(BindingAction<State>)
    case cancelButtonTapped
    case destination(PresentationAction<Destination.Action>)
    case resetGainTapped
    case resetPanTapped
    case saveButtonTapped
    case tuning(Tuning.Action)
    case useLowestKeyTapped
    case useOriginalNameTapped
  }

  public init() {}

  @Dependency(\.dismiss) var dismiss
  @Shared(.confirmPresetHiding) private var confirmPresetHiding

  public var body: some ReducerOf<Self> {
    BindingReducer()
    Scope(state: \.tuning, action: \.tuning) { Tuning() }

    Reduce { state, action in

      log.action("PresetEditor", action)

      switch action {

      case .binding(\.gainSlider):
        return gainSliderChanged(&state)

      case .binding(\.panSlider):
        return panSliderChanged(&state)

      case .binding(\.visible):
        if !state.visible {
          return confirmHidePreset(&state)
        }
        return .none

      case .cancelButtonTapped:
        return dismiss(&state, save: false)

      case .destination(.presented(.alert(.hidePresetConfirmed))):
        return hidePresetConfirmed(&state)

      case .resetGainTapped:
        state.gainSlider = AudioConfig.defaultGain
        return.none

      case .resetPanTapped:
        state.panSlider = AudioConfig.defaultPan
        return.none

      case .saveButtonTapped:
        return dismiss(&state, save: true)

      case .useLowestKeyTapped:
        return useLowestKey(&state)

      case .useOriginalNameTapped:
        state.displayName = state.preset.originalName
        return .none

      default:
        return .none
      }
    }
    .ifLet(\.destination, action: \.destination)
  }
}

extension PresetEditor {

  private func confirmHidePreset(_ state: inout State) -> Effect<Action> {
    if confirmPresetHiding {
      state.visible = true
      state.destination = .alert(
        .confirmHidePreset(action: .hidePresetConfirmed, displayName: state.displayName)
      )
      return .none
    }
    return hidePresetConfirmed(&state)
  }

  private func dismiss(_ state: inout State, save: Bool) -> Effect<Action> {
    if save {
      state.save()
    }
    return .run { [dismiss] _ in await dismiss() }
  }

  private func gainSliderChanged(_ state: inout State) -> Effect<Action> {
    guard state.isActive else { return .none }
    guard let parameterTree = state.audioUnit?.parameterTree else { return .none }
    state.pendingAudioConfig.gain = state.gainSlider
    let gainAddress = AUParameterAddress(SF2.Entity.Generator.Index.initialAttenuation.rawValue)
    let parameter = parameterTree.parameter(withAddress: gainAddress)
    unsafe parameter?.setValue(state.pendingAudioConfig.gain.gainGeneratorValue, originator: nil)
    return .none
  }

  private func hidePresetConfirmed(_ state: inout State) -> Effect<Action> {
    $confirmPresetHiding.withLock { $0 = false }
    state.visible = false
    return .none
  }

  private func panSliderChanged(_ state: inout State) -> Effect<Action> {
    guard state.isActive else { return .none }
    state.pendingAudioConfig.gain = state.gainSlider
    guard let parameterTree = state.audioUnit?.parameterTree else { return .none }
    let panAddress = AUParameterAddress(SF2.Entity.Generator.Index.pan.rawValue)
    let parameter = parameterTree.parameter(withAddress: panAddress)
    unsafe parameter?.setValue(state.pendingAudioConfig.pan.panGeneratorValue, originator: nil)
    return .none
  }

  private func useLowestKey(_ state: inout State) -> Effect<Action> {
    @Shared(.firstVisibleKey) var lowestKey
    state.pendingAudioConfig.keyboardLowestNote = lowestKey
    return .none
  }
}

extension PresetEditor.Destination.State: Equatable {}
extension PresetEditor.Destination.State: _EphemeralState {
  public typealias Action = Alert
}

// MARK: - View

public struct PresetEditorView: View {
  @Bindable private var store: StoreOf<PresetEditor>
  @Shared(.firstVisibleKey) private var lowestKey

  public init(store: StoreOf<PresetEditor>) {
    self.store = store
  }

  public var body: some View {
    NavigationStack {
      Form {
        nameSection
        keyboardSection
        audioSection
        midiSection
        tuningSection
        notesSection
        infoSection
      }
      .font(.presetEditor)
      .navigationTitle("Preset Editor")
      .toolbar {
        ToolbarItem(placement: .cancellationAction) {
          Button {
            store.send(.cancelButtonTapped, animation: .default)
          } label: {
            Image(systemName: .cancelButtonImageName)
          }
        }
        ToolbarItem(placement: .confirmationAction) {
          Button {
            store.send(.saveButtonTapped, animation: .default)
          } label: {
            Image(systemName: .saveButtonImageName)
          }
        }
      }
    }
    .alert($store.scope(state: \.destination?.alert, action: \.destination.alert))
  }

  var nameSection: some View {
    Section {
      if !store.isFavorite {
        Toggle("Visible", isOn: $store.visible)
          .circledCheckMarkToggleStyle()
      }
      NameFieldView(text: $store.displayName, readOnly: false)
      HStack {
        Text(store.preset.originalName)
          .foregroundStyle(.secondary)
        Spacer()
        Button {
          store.send(.useOriginalNameTapped)
        } label: {
          Text("Original")
        }
      }
    }
  }

  var keyboardSection: some View {
    Section(header: Text("Shift Keyboard")) {
      Toggle("Enabled", isOn: $store.pendingAudioConfig.keyboardLowestNoteEnabled)
        .circledCheckMarkToggleStyle()
      HStack {
        Text("First key:")
        // Spacer()
        Text(store.pendingAudioConfig.keyboardLowestNote.label)
          .frame(maxWidth: .infinity, alignment: Alignment.center)
        Stepper(
          "",
          value: $store.pendingAudioConfig.keyboardLowestNote,
          in: Note(midiNoteValue: 0)...Note(midiNoteValue: 127),
          step: 1
        )
        .labelsHidden()
        .disabled(!store.pendingAudioConfig.keyboardLowestNoteEnabled)
      }
      HStack {
        Text("Current:")
        Text(lowestKey.label)
          .frame(maxWidth: .infinity, alignment: Alignment.center)
        Button {
          store.send(.useLowestKeyTapped)
        } label: {
          Text("Use")
        }
        .disabled(!store.pendingAudioConfig.keyboardLowestNoteEnabled)
      }
    }
  }

  var notesSection: some View {
    Section(header: Text("Notes")) {
      TextEditor(text: $store.notes)
    }
  }

  var infoSection: some View {
    Section(header: Text("Contents")) {
      LabeledContent("SoundFont", value: store.soundFontName)
      LabeledContent("Address", value: "Bank: \(store.preset.bank) Index: \(store.preset.program)")
      LabeledContent("Index", value: "\(store.preset.index)")
      LabeledContent("Id", value: "\(store.preset.id)")
    }.font(.footnote)
  }

  var formattedGainValue: String {
    .localizedStringWithFormat("%+.1f dB", store.gainSlider)
  }

  var formattedLeftPanValue: String {
    .localizedStringWithFormat("%d", 100 - Int(round((store.panSlider + 100.0) / 2.0)))
  }

  var formattedRightPanValue: String {
    .localizedStringWithFormat("%d", Int(round((store.panSlider + 100.0) / 2.0)))
  }

  var midiSection: some View {
    Section(header: Text("MIDI")) {
      HStack(spacing: 10) {
        Text("Pitch bend range (semitones):")
        Spacer()
        Text("\(store.pendingAudioConfig.pitchBendRange)")
        Spacer()
        Stepper("", value: $store.pendingAudioConfig.pitchBendRange, in: 1...24, step: 1)
          .labelsHidden()
      }
    }
  }

  var audioSection: some View {
    Section(header: Text("Audio")) {
      HStack {
        LabeledContent("Gain", value: formattedGainValue)
        Button {
          store.send(.resetGainTapped)
        } label: {
          Text("Reset")
        }
      }
      Slider(value: $store.gainSlider, in: AudioConfig.minGain...AudioConfig.maxGain) {
      } minimumValueLabel: {
        Text("-90 db")
      } maximumValueLabel: {
        Text("+12 db")
      } onEditingChanged: { editing in
        if !editing {
          print("gainSlider finished")
        }
      }
      HStack {
        LabeledContent("Pan", value: "\(formattedLeftPanValue)/\(formattedRightPanValue)")
        Button {
          store.send(.resetPanTapped)
        } label: {
          Text("Reset")
        }
      }
      Slider(value: $store.panSlider, in: AudioConfig.minPan...AudioConfig.maxPan) {
      } minimumValueLabel: {
        Text("L")
      } maximumValueLabel: {
        Text("R")
      } onEditingChanged: { editing in
        if !editing {
          print("panSlider finished")
        }
      }
    }
  }

  var tuningSection: some View {
    Section("Tuning") {
      TuningView(store: store.scope(state: \.tuning, action: \.tuning))
    }
  }
}

extension AVAudioUnitReverbPreset: @retroactive Strideable {
  public func distance(to other: AVAudioUnitReverbPreset) -> Int {
    other.rawValue - self.rawValue
  }

  public func advanced(by distance: Int) -> AVAudioUnitReverbPreset {
    // swiftlint:disable:next force_unwrapping
    .init(rawValue: self.rawValue + distance)!
  }

  public typealias Stride = Int
}

extension View {

  public func presetEditorSheet(_ store: Binding<StoreOf<PresetEditor>?>) -> some View {
    self
      .sheet(item: store) {
        PresetEditorView(store: $0)
      }
  }
}

#if DEBUG

extension PresetEditorView {
  static var preview: some View {
    let presets = Preset.all(for: 1)
    return PresetEditorView(store: Store(initialState: .init(sectionId: .init(0), preset: presets[0], isActive: false)) {
      PresetEditor()
    })
  }
}

#Preview {
  // swiftlint:disable:next redundant_discardable_let
  let _ = prepareDependencies {
    installApplicationFont()
    navigationBarTitleStyle()
    $0.defaultDatabase = previewDatabase()
  }
  PresetEditorView.preview
}

#endif // DEBUG
