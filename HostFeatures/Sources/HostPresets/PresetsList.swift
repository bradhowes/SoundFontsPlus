// Copyright © 2025 Brad Howes. All rights reserved.

import AudioToolbox
import ComposableArchitecture
import Dependencies
import DependenciesMacros
import HostSupport
import OSLog
import SwiftUI
import TypedFullState

/**
 Manages a list of Preset values. New entries can be created, names can be changed, and existing entries
 can be deleted.
 */
@Reducer
public struct PresetsList {

  @Reducer
  public enum Destination {
    case presetEditor(PresetEditor)
  }

  @ObservableState
  public struct State: Equatable {
    @Presents public var destination: Destination.State?
    public var rows: IdentifiedArrayOf<PresetButton.State>

    public init(rows: IdentifiedArrayOf<PresetButton.State> = []) {
      self.rows = rows
    }
  }

  public enum Action {
    case addButtonTapped
    case delegate(Delegate)
    case destination(PresentationAction<Destination.Action>)
    case initialize
    case updateActivePreset(fullStates: TypedFullStateCollection)
    case rows(IdentifiedActionOf<PresetButton>)
    case saveButtonTapped

    @CasePathable
    public enum Delegate {
      case presetActivated(fullStates: TypedFullStateCollection)
      case updateActivePresetRequested
    }
  }

  public init() {}

  @Dependency(\.uuid) var uuid
  @Dependency(\.presetsStore) var presetsStore

  public var body: some ReducerOf<Self> {

    Reduce { state, action in
      log.action("PressetsList", action)
      switch action {
      case .addButtonTapped: return addButtonTapped(&state)
      case .delegate: return .none
      case .destination(.presented(.presetEditor(.delegate(.accepted(let name))))): return editorDismissed(&state, name: name)
      case .destination: return .none
      case .initialize: return initialize(&state)
      case .rows(.element(id: let id, action: .delegate(let action))): return processRowAction(&state, id: id, action: action)
      case .rows: return .none
      case .saveButtonTapped: return updateActivePresetRequested(&state)
      case .updateActivePreset(let fullStates): return updateActivePreset(&state, fullStates: fullStates)
      }
    }
    .forEach(\.rows, action: \.rows) {
      PresetButton()
    }
    .ifLet(\.$destination, action: \.destination)
  }
}

extension PresetsList {

  private func addButtonTapped(_ state: inout State) -> Effect<Action> {
    log.info("addButtonTapped BEGIN")
    state.rows.append(PresetButton.State(preset: .init(name: "New Preset", id: uuid(), fullStateCollection: .init())))
    log.info("addButtonTapped EBD")
    return .none
  }

  private func editorDismissed(_ state: inout State, name: String) -> Effect<Action> {
    let id = state.destination?.presetEditor?.id
    let index = state.rows.firstIndex(where: {$0.preset.id == id})
    log.info("state.destination?.presetEditor?.id: \(String(describing: id))")
    log.info("\(String(describing: index))")
    if let index {
      state.rows[index].preset.name = name
    }
    return updateActivePresetRequested(&state)
  }

  private func initialize(_ state: inout State) -> Effect<Action> {
    log.info("initialize BEGIN")
    guard let data = presetsStore.restore() else {
      log.info("failed to reestore presets from disk - creating empty collection")
      state.rows = []
      return .none
    }

    do {
      let presets = try JSONDecoder().decode(Array<Preset>.self, from: data)
      state.rows = .init(uniqueElements: presets.map { .init(preset: $0) })
    } catch {
      log.error("initialize - failed to decode presets: \(error.localizedDescription)")
    }

    log.info("initialize END")
    return .none
  }

  private func processRowAction(
    _ state: inout State,
    id: PresetButton.State.ID,
    action: PresetButton.Action.Delegate
  ) -> Effect<Action> {
    log.action("processRowAction", action)
    switch action {
    case .activate(fullStates: let fullStates): return .send(.delegate(.presetActivated(fullStates: fullStates)))
    case .delete(id: let id): state.rows.remove(id: id)
    case .edit(id: let id, name: let name): state.destination = .presetEditor(.init(id: id, name: name))
    }
    log.info("processRowAction END")
    return .none
  }

  private func savePresets(_ state: inout State) -> Effect<Action> {
    log.info("savePresets BEGIN")
    do {
      let data = try JSONEncoder().encode(state.rows.map { $0.preset })
      presetsStore.save(data)
      log.info("savePresets - saved")
    } catch {
      log.error("failed to save presets: \(error.localizedDescription)")
    }

    log.info("savePresets END")
    return .none
  }

  private func updateActivePreset(_ state: inout State, fullStates: TypedFullStateCollection) -> Effect<Action> {
    log.info("updateActivePreset BEGIN")
    @Shared(.activePreset) var activePreset
    if let activePreset,
       state.rows.index(id: activePreset) != nil {
      return .concatenate(
        .send(.rows(.element(id: activePreset, action: .updated(fullStates)))),
        savePresets(&state)
      )
    }
    log.info("updateActivePreset END")
    return savePresets(&state)
  }

  private func updateActivePresetRequested(_ state: inout State) -> Effect<Action> {
    log.info("updateActivePresetRequested BEGIN")
    return .send(.delegate(.updateActivePresetRequested))
  }
}

extension PresetsList.Destination.State: Equatable {}

public struct PresetsListView: View {
  @Bindable private var store: StoreOf<PresetsList>

  public init(store: StoreOf<PresetsList>) {
    self.store = store
  }

  public var body: some View {
    VStack {
      HStack(spacing: 32) {
        Text("Presets")
          .bold()
        HStack(spacing: 16) {
          Button {
            store.send(.saveButtonTapped)
          } label: {
            Text("Save")
          }
          .disabled(store.rows.isEmpty)
          Button {
            store.send(.addButtonTapped)
          } label: {
            Image(systemName: "plus")
          }
        }
        .buttonStyle(.bordered)
        .imageScale(.large)
      }
      List {
        ForEach(store.scope(state: \.rows, action: \.rows)) { store in
          PresetButtonView(store: store)
        }
      }
    }
    .padding()
    .animation(.smooth, value: store.rows)
    .sheet(item: $store.scope(state: \.destination?.presetEditor, action: \.destination.presetEditor)) {
      PresetEditorView(store: $0)
    }
  }
}

#if DEBUG

extension PresetsListView {

  static var preview: some View {
    prepareDependencies {
      $0.uuid = .incrementing
      $0.presetsStore = .previewValue
      return PresetsListView(store: Store(initialState: .init()) { PresetsList() })
    }
  }
}

#Preview {
  PresetsListView.preview
}

#endif // DEBUG

private let log = Logger(category: "PresetsList")
