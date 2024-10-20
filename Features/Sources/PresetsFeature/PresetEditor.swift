// Copyright © 2024 Brad Howes. All rights reserved.

import ComposableArchitecture
import SwiftUI
import Models
import Tagged

@Reducer
public struct PresetEditor {

  @ObservableState
  public struct State: Equatable {
    var preset: PresetModel
    var audioSettings: AudioSettingsModel
    var displayName: String

    public init(preset: PresetModel) {
      self.preset = preset
      self.audioSettings = preset.audioSettings ?? .init()
      self.displayName = preset.displayName
    }
  }

  public enum Action: BindableAction {
    case acceptButtonTapped
    case binding(BindingAction<State>)
    case dismissButtonTapped

    case nameChanged(String)
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

  @Dependency(\.dismiss) var dismiss

  public var body: some ReducerOf<Self> {
    BindingReducer()
    Reduce { state, action in
      switch action {

      case .acceptButtonTapped:
        save(&state)
        let dismiss = dismiss
        return .run { _ in await dismiss() }

      case .binding:
        return .none

      case .dismissButtonTapped:
        let dismiss = dismiss
        return .run { _ in await dismiss() }

      case .nameChanged(let name):
        if name != state.displayName {
          setName(&state, name: name)
        }
        return .none

      case .useOriginalNameTapped:
        setName(&state, name: state.preset.originalName)
        return .none
      }
    }
  }

  public init() {}
}

extension PresetEditor {

  private func setName(_ state: inout State, name: String) {
    state.displayName = name
  }

  private func save(_ state: inout State) {
    @Dependency(\.modelContextProvider) var context
    state.preset.displayName = state.displayName
    do {
      try context.save()
    } catch {
      print("error encountered saving changes to preset - \(error.localizedDescription)")
    }
  }
}

public struct PresetEditorView: View {
  @Bindable var store: StoreOf<PresetEditor>
  @FocusState var displayNameHasFocus: Bool

  public var body: some View {
    NavigationStack {
      Form {
        Section(header: Text("Name")) {
          TextField("", text: $store.displayName.sending(\.nameChanged))
            .focused($displayNameHasFocus)
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
        Section(header: Text("Keyboard")) {
          HStack {
            Text("Adjust Keyboard")
            Spacer()
            Toggle("Adjust Keyboard", isOn: $store.audioSettings.keyboardLowestNoteEnabled)
          }
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
    }
  }
}
