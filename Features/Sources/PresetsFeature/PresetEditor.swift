// Copyright © 2025 Brad Howes. All rights reserved.

import ComposableArchitecture
import GRDB
import Models
import SF2ResourceFiles
import SwiftUI

@Reducer
public struct PresetEditor: Equatable {

  @ObservableState
  public struct State: Equatable {
    var preset: Preset
    var displayName: String
    var visible: Bool
    var notes: String

    public init(preset: Preset) {
      self.preset = preset
      self.displayName = preset.displayName
      self.visible = preset.visible
      self.notes = preset.notes
    }
  }

  public enum Action: Equatable, BindableAction {
    case acceptButtonTapped
    case binding(BindingAction<State>)
    case dismissButtonTapped
    case useOriginalNameTapped

//    case adjustKeyboardToggled(Bool)
//    case firstNoteDecrementTapped
//    case firstNoteIncrementTapped
//    case firstNoteCurrentTapped
//    case shiftA4DecrementTapped
//    case shiftA4IncrementTapped
//    case standardTuningTapped
//    case scientificTuningTapped
//    case centsChanged(String)
//    case a4FrequencyChanged(String)
//    case pitchBendDecrementTapped
//    case pitchBendIncrementTapped
//    case pitchBendCurrentTapped
//    case gainSliderChanged(String)
//    case panSliderChanged(String)
  }

  public var body: some ReducerOf<Self> {
    Reduce { state, action in
      switch action {
      case .acceptButtonTapped: return save(&state)
      case .binding: return .none
      case .dismissButtonTapped: return dismiss()
      case .useOriginalNameTapped: return setName(&state, value: state.preset.originalName)
      }
    }
    BindingReducer()
  }

  public init() {}
}

extension PresetEditor {

  private func dismiss() -> Effect<Action> {
    return .run { _ in
      @Dependency(\.dismiss) var dismiss
      await dismiss() }
  }

  private func setName(_ state: inout State, value: String) -> Effect<Action> {
    state.displayName = value
    return .none
  }

  private func save(_ state: inout State) -> Effect<Action> {
    @Dependency(\.defaultDatabase) var db
    let displayName = state.displayName.trimming(while: \.isWhitespace)
    if !displayName.isEmpty {
      state.preset.displayName = state.displayName
    }
    state.preset.notes = state.notes
    state.preset.visible = state.visible
    try? db.write { try state.preset.save($0) }
    return dismiss()
  }
}

enum Field {
  case displayName
  case notes
}

public struct PresetEditorView: View {
  @Bindable var store: StoreOf<PresetEditor>
  @FocusState var focusField: Field?

  public var body: some View {
    NavigationStack {
      Form {
        Section(header: Text("Name")) {
          TextField("", text: $store.displayName)
            .focused($focusField, equals: .displayName)
            .textFieldStyle(.roundedBorder)
        }
        Section(header: Text("Original Name")) {
          HStack {
            Text(store.preset.originalName)
            Spacer()
            Button {
              store.send(.useOriginalNameTapped)
            } label: {
              Text("Use")
            }
          }
        }
        Toggle("Visible", isOn: $store.visible)
        Section(header: Text("Keyboard")) {
          HStack {
            Text("Adjust Keyboard")
            Spacer()
//            Toggle("Adjust Keyboard", isOn: $store.audioSettings.keyboardLowestNoteEnabled)
//              .labelsHidden()
          }
        }
        Section(header: Text("Notes")) {
          TextEditor(text: $store.notes)
            .focused($focusField, equals: .notes)
        }
      }
      .navigationTitle("Preset")
      .toolbar {
        ToolbarItem(placement: .cancellationAction) {
          Button("Cancel") {
            store.send(.dismissButtonTapped, animation: .default)
          }
        }
        ToolbarItem(placement: .automatic) {
          Button("Accept") {
            store.send(.acceptButtonTapped, animation: .default)
          }
        }
      }
    }.onAppear {
      focusField = .displayName
    }
  }
}

extension PresetEditorView {
  static var preview: some View {
    let _ = prepareDependencies {
      $0.defaultDatabase = Support.previewDatabase
    }

    @Dependency(\.defaultDatabase) var db
    let presets = try! db.read { try! Preset.fetchAll($0) }

    return PresetEditorView(store: Store(initialState: .init(preset: presets[0])) { PresetEditor() })
  }
}

#Preview {
  PresetEditorView.preview
}
