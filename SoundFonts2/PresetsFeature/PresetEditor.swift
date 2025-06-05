// Copyright © 2025 Brad Howes. All rights reserved.

import ComposableArchitecture
import SharingGRDB
import SwiftUI

@Reducer
public struct PresetEditor: Equatable {

  @ObservableState
  public struct State: Equatable, Sendable {
    let preset: Preset
    let soundFontName: String

    var displayName: String
    var visible: Bool
    var notes: String

    var audioConfig: AudioConfig.Draft
    var delayConfig: DelayConfig.Draft
    var reverbConfig: ReverbConfig.Draft

    var tuning: TuningFeature.State

    var isFavorite: Bool { preset.kind == .favorite }

    public init(preset: Preset) {
      self.preset = preset
      self.displayName = preset.displayName
      self.visible = preset.kind == .preset
      self.notes = preset.notes
      self.soundFontName = preset.soundFontName
      let audioConfig = preset.audioConfig
      let audioConfigDraft = preset.audioConfigDraft
      self.audioConfig = audioConfigDraft
      self.delayConfig = audioConfig?.delayConfigDraft ?? .init()
      self.reverbConfig = audioConfig?.reverbConfigDraft ?? .init()
      self.tuning = .init(frequency: audioConfigDraft.customTuning, enabled: audioConfigDraft.customTuningEnabled)
    }

    public mutating func save() {
      displayName = displayName.trimmed(or: preset.displayName)
      notes = notes.trimmed(or: preset.notes)

      @Dependency(\.defaultDatabase) var database
      try? database.write { db in
        try Preset.update {
          $0.displayName = displayName
          $0.notes = notes
          if !isFavorite {
            $0.kind = visible ? .preset : .hidden
          }
        }
        .where { $0.id == preset.id }
        .execute(db)

        // If no changes from default config values then we are done.
        guard audioConfig != AudioConfig.Draft() ||
                delayConfig != DelayConfig.Draft() ||
                reverbConfig != ReverbConfig.Draft() else {
          return
        }

        precondition(audioConfig.presetId == nil || audioConfig.presetId == preset.id)

        audioConfig.presetId = preset.id

        guard let audioConfigId = (try AudioConfig
          .upsert(audioConfig)
          .returning(\.id)
          .fetchOne(db)
        ) else {
          print("*** failed to upsert audioConfig")
          return
        }

        print("audioConfigId: \(audioConfigId)")

        if delayConfig != DelayConfig.Draft() {
          delayConfig.audioConfigId = audioConfigId
          let delayConfigId = try DelayConfig
            .upsert(delayConfig)
            .returning(\.id)
            .fetchOne(db)
          print("delayConfigId: \(delayConfigId ?? -1)")
        }

        if reverbConfig != ReverbConfig.Draft() {
          reverbConfig.audioConfigId = audioConfigId
          let reverbConfigId = try ReverbConfig
            .upsert(reverbConfig)
            .returning(\.id)
            .fetchOne(db)
          print("reverbConfigId: \(reverbConfigId ?? -1)")
        }
      }
    }
  }

  public enum Action: Equatable, BindableAction {
    case binding(BindingAction<State>)
    case cancelButtonTapped
    case displayNameChanged(String)
    case notesChanged(String)
    case resetGainTapped
    case resetPanTapped
    case saveButtonTapped
    case tuning(TuningFeature.Action)
    case useLowestKeyTapped
    case useOriginalNameTapped
  }

  public var body: some ReducerOf<Self> {
    BindingReducer()
    Scope(state: \.tuning, action: \.tuning) { TuningFeature() }
    Reduce { state, action in
      switch action {
      case .binding: return .none
      case .cancelButtonTapped: return dismiss(&state, save: false)
      case .displayNameChanged(let value): return updateName(&state, value: value)
      case .notesChanged(let value): return updateNotes(&state, value: value)
      case .resetGainTapped:
        state.audioConfig.gain = 0.0
        return.none
      case .resetPanTapped:
        state.audioConfig.pan = 0.0
        return.none
      case .saveButtonTapped: return dismiss(&state, save: true)
      case .tuning: return .none
      case .useLowestKeyTapped: return useLowestKey(&state)
      case .useOriginalNameTapped: return updateName(&state, value: state.preset.originalName)
      }
    }
  }

  public init() {}
}

extension PresetEditor {

  private func dismiss(_ state: inout State, save: Bool) -> Effect<Action> {
    if save {
      state.save()
    }
    @Dependency(\.dismiss) var dismiss
    return .run { _ in await dismiss() }
  }

  private func updateName(_ state: inout State, value: String) -> Effect<Action> {
    state.displayName = value
    return .none
  }

  private func updateNotes(_ state: inout State, value: String) -> Effect<Action> {
    state.notes = value
    return .none
  }

  private func useLowestKey(_ state: inout State) -> Effect<Action> {
    @Shared(.firstVisibleKey) var lowestKey
    state.audioConfig.keyboardLowestNote = lowestKey
    return .none
  }
}

enum Field {
  case displayName
  case notes
}

public struct PresetEditorView: View {
  @Bindable private var store: StoreOf<PresetEditor>
  @FocusState private var focusField: Field?
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
        delaySection
        reverbSection
        midiSection
        tuningSection
        notesSection
        infoSection
      }
      .navigationTitle("Preset")
      .toolbar {
        ToolbarItem(placement: .cancellationAction) {
          Button("Cancel") {
            store.send(.cancelButtonTapped, animation: .default)
          }
        }
        ToolbarItem(placement: .confirmationAction) {
          Button("Save") {
            store.send(.saveButtonTapped, animation: .default)
          }
        }
      }
    }.onAppear {
      focusField = .displayName
    }
  }

  var nameSection: some View {
    Section {
      if !store.isFavorite {
        Toggle("Visible", isOn: $store.visible)
      }
      TextField("Name", text: $store.displayName.sending(\.displayNameChanged))
        .focused($focusField, equals: .displayName)
        .textFieldStyle(.roundedBorder)
      HStack {
        Button {
          store.send(.useOriginalNameTapped)
        } label: {
          Text("Original")
        }
        Spacer()
        Text(store.preset.displayName)
          .foregroundStyle(.secondary)
      }
    }
  }

  var keyboardSection: some View {
    Section(header: Text("Shift Keyboard")) {
      Toggle("Enabled", isOn: $store.audioConfig.keyboardLowestNoteEnabled)
      HStack {
        Text("First key:")
        Spacer()
        Text(store.audioConfig.keyboardLowestNote.label)
        Spacer()
        Stepper(
          "",
          value: $store.audioConfig.keyboardLowestNote,
          in: Note(midiNoteValue: 0)...Note(midiNoteValue: 127),
          step: 1
        )
        .labelsHidden()
        .disabled(!store.audioConfig.keyboardLowestNoteEnabled)
      }
      HStack {
        Button {
          store.send(.useLowestKeyTapped)
        } label: {
          Text("Current")
        }
        .disabled(!store.audioConfig.keyboardLowestNoteEnabled)
        Spacer()
        Text(lowestKey.label)
      }
    }
  }

  var notesSection: some View {
    Section(header: Text("Notes")) {
      TextEditor(text: $store.notes.sending(\.notesChanged))
        .focused($focusField, equals: .notes)
    }
  }

  var infoSection: some View {
    Section(header: Text("Contents")) {
      LabeledContent("SoundFont", value: store.soundFontName)
      LabeledContent("Address", value: "Bank: \(store.preset.bank) Index: \(store.preset.program)")
    }.font(.footnote)
  }

  var formattedGainValue: String {
    String(format: "%+.1f dB", locale: Locale.current, arguments: [store.audioConfig.gain])
  }

  var formattedLeftPanValue: String {
    let value = 100 - Int(round((store.audioConfig.pan + 100.0) / 200.0 * 100.0))
    return String(format: "%d", locale: Locale.current, arguments: [value])
  }

  var formattedRightPanValue: String {
    let value = Int(round((store.audioConfig.pan + 100.0) / 200.0 * 100.0))
    return String(format: "%d", locale: Locale.current, arguments: [value])
  }

  var midiSection: some View {
    Section(header: Text("MIDI")) {
      HStack(spacing: 10) {
        Text("Pitch bend range (semitones):")
        Spacer()
        Text("\(store.audioConfig.pitchBendRange)")
        Spacer()
        Stepper("", value: $store.audioConfig.pitchBendRange, in: 1...24, step: 1)
          .labelsHidden()
      }
    }
  }

  var audioSection: some View {
    Section(header: Text("Audio")) {
      LabeledContent("Gain", value: formattedGainValue)
      HStack {
        Slider(
          value: $store.audioConfig.gain,
          in: -90...12
        )
        Button {
          store.send(.resetGainTapped)
        } label: {
          Text("Reset")
        }
      }
      ZStack {
        Text("Pan")
        HStack {
          Text(formattedLeftPanValue)
          Spacer()
          Text(formattedRightPanValue)
        }
      }
      HStack {
        Slider(value: $store.audioConfig.pan, in: -100...100)
        Button {
          store.send(.resetPanTapped)
        } label: {
          Text("Reset")
        }
      }
    }
  }

  var delaySection: some View {
    Section(header: Text("Delay")) {
      Toggle("Enabled", isOn: $store.delayConfig.enabled)
      HStack {
        Text("Time:")
        Spacer()
        Text("\(store.delayConfig.time) ms")
      }
      Slider(value: $store.delayConfig.time, in: 0...2000)
        .disabled(!store.delayConfig.enabled)
      HStack {
        Text("Feedback:")
        Spacer()
        Text("\(store.delayConfig.feedback)%")
      }
      Slider(value: $store.delayConfig.feedback, in: -100...100)
        .disabled(!store.delayConfig.enabled)
      HStack {
        Text("Cutoff:")
        Spacer()
        Text("\(store.delayConfig.cutoff)")
      }
      Slider(value: $store.delayConfig.cutoff, in: 12...20000)
        .disabled(!store.delayConfig.enabled)
      HStack {
        Text("WetDry:")
        Spacer()
        Text("\(store.delayConfig.wetDryMix)")
      }
      Slider(value: $store.delayConfig.wetDryMix, in: 0...100)
        .disabled(!store.delayConfig.enabled)
    }
  }

  var reverbSection: some View {
    Section(header: Text("Reverb")) {
      Toggle("Enabled", isOn: $store.reverbConfig.enabled)
      HStack {
        Text("Preset:")
        Spacer()
        Text("\(store.reverbConfig.preset)")
        Spacer()
        Stepper("", value: $store.reverbConfig.preset, in: 0...11)
          .labelsHidden()
          .disabled(!store.reverbConfig.enabled)
      }
      HStack {
        Text("WetDry:")
        Spacer()
        Text("\(store.reverbConfig.wetDryMix)")
      }
      Slider(value: $store.reverbConfig.wetDryMix, in: 0...100)
        .disabled(!store.reverbConfig.enabled)
    }
  }

  var tuningSection: some View {
    TuningView(store: Store(initialState: store.tuning) { TuningFeature() })
  }
}

extension PresetEditorView {
  static var preview: some View {
    let _ = prepareDependencies {
      $0.defaultDatabase = try! appDatabase()
    }

    let presets = Operations.presets
    return PresetEditorView(store: Store(initialState: .init(preset: presets[0])) { PresetEditor() })
  }
}

#Preview {
  PresetEditorView.preview
}
