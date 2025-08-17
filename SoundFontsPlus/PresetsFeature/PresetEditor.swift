// Copyright © 2025 Brad Howes. All rights reserved.

import AVFoundation
import ComposableArchitecture
import SharingGRDB
import SwiftUI

@Reducer
public struct PresetEditor {

  @ObservableState
  public struct State: Equatable, Sendable {
    let sectionId: Int
    let preset: Preset
    let soundFontName: String

    var displayName: String
    var originalName: String
    var visible: Bool
    var notes: String

    var audioConfig: AudioConfig.Draft
    var tuning: TuningFeature.State

    var isFavorite: Bool { preset.kind == .favorite }

    public init(sectionId: Int, preset: Preset) {
      self.sectionId = sectionId
      self.preset = preset
      self.displayName = preset.displayName
      self.originalName = preset.originalName
      self.visible = preset.kind == .preset
      self.notes = preset.notes
      let audioConfigDraft = preset.audioConfigDraft
      self.soundFontName = preset.soundFontName
      self.audioConfig = audioConfigDraft
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
        guard audioConfig.id != nil else { return }

        withErrorReporting {
          try AudioConfig.upsert {
            audioConfig
          }.execute(db)
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
    }
  }

  var nameSection: some View {
    Section {
      if !store.isFavorite {
        Toggle("Visible", isOn: $store.visible)
      }
      NameFieldView(text: $store.displayName.sending(\.displayNameChanged), readOnly: false)
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
      Toggle("Enabled", isOn: $store.audioConfig.keyboardLowestNoteEnabled)
      HStack {
        Text("First key:")
        // Spacer()
        Text(store.audioConfig.keyboardLowestNote.label)
          .frame(maxWidth: .infinity, alignment: Alignment.center)
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
        Text("Current:")
        Text(lowestKey.label)
          .frame(maxWidth: .infinity, alignment: Alignment.center)
        Button {
          store.send(.useLowestKeyTapped)
        } label: {
          Text("Use")
        }
        .disabled(!store.audioConfig.keyboardLowestNoteEnabled)
      }
    }
  }

  var notesSection: some View {
    Section(header: Text("Notes")) {
      TextEditor(text: $store.notes.sending(\.notesChanged))
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

  var tuningSection: some View {
    TuningView(store: Store(initialState: store.tuning) { TuningFeature() })
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

extension PresetEditorView {
  static var preview: some View {
    prepareDependencies {
      // swiftlint:disable:next force_try
      $0.defaultDatabase = try! appDatabase()
      navigationBarTitleStyle()
    }

    let presets = Operations.presets
    return PresetEditorView(store: Store(initialState: .init(sectionId: 0, preset: presets[0])) { PresetEditor() })
  }
}

#Preview {
  PresetEditorView.preview
}
