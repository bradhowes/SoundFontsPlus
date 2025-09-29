// Copyright © 2025 Brad Howes. All rights reserved.

import AVFoundation
import ComposableArchitecture
import SQLiteData
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

    let originalAudioConfig: AudioConfig.Draft
    var pendingAudioConfig: AudioConfig.Draft

    var gainSlider: Double
    var panSlider: Double
    var tuning: TuningFeature.State

    var isFavorite: Bool { preset.kind == .favorite }

    public init(sectionId: Int, preset: Preset) {
      self.sectionId = sectionId
      self.preset = preset
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
    }

    public mutating func save() {
      displayName = displayName.trimmed(or: preset.displayName)
      notes = notes.trimmed(or: preset.notes)

      pendingAudioConfig.gain = gainSlider
      pendingAudioConfig.pan = panSlider

      pendingAudioConfig.customTuning = tuning.frequency
      pendingAudioConfig.customTuningEnabled = tuning.enabled

      withDatabaseWriter { db in
        try Preset.update {
          $0.displayName = displayName
          $0.notes = notes
          if !isFavorite {
            $0.kind = visible ? .preset : .hidden
          }
        }
        .where { $0.id == preset.id }
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
      case .binding:
        return .none

      case .cancelButtonTapped:
        return dismiss(&state, save: false)

      case .displayNameChanged(let value):
        state.displayName = value
        return .none

      case .notesChanged(let value):
        state.notes = value
        return .none

      case .resetGainTapped:
        state.gainSlider = 0.0
        return.none

      case .resetPanTapped:
        state.panSlider = 0.0
        return.none

      case .saveButtonTapped:
        return dismiss(&state, save: true)

      case .tuning:
        return .none

      case .useLowestKeyTapped:
        return useLowestKey(&state)

      case .useOriginalNameTapped:
        state.displayName = state.preset.originalName
        return .none
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

  private func useLowestKey(_ state: inout State) -> Effect<Action> {
    @Shared(.firstVisibleKey) var lowestKey
    state.pendingAudioConfig.keyboardLowestNote = lowestKey
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
          .font(.button)
        }
        ToolbarItem(placement: .confirmationAction) {
          Button("Save") {
            store.send(.saveButtonTapped, animation: .default)
          }
          .font(.button)
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
      Toggle("Enabled", isOn: $store.pendingAudioConfig.keyboardLowestNoteEnabled)
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
    String(format: "%+.1f dB", locale: Locale.current, arguments: [store.gainSlider])
  }

  var formattedLeftPanValue: String {
    let value = 100 - Int(round((store.panSlider + 100.0) / 200.0 * 100.0))
    return String(format: "%d", locale: Locale.current, arguments: [value])
  }

  var formattedRightPanValue: String {
    let value = Int(round((store.panSlider + 100.0) / 200.0 * 100.0))
    return String(format: "%d", locale: Locale.current, arguments: [value])
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
      LabeledContent("Gain", value: formattedGainValue)
      HStack {
        Slider(
          value: $store.gainSlider,
          in: 0...100
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
        Slider(value: $store.panSlider, in: -100...100)
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
