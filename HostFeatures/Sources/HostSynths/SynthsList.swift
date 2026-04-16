// Copyright © 2025 Brad Howes. All rights reserved.

import AudioToolbox
import ComposableArchitecture
import Sharing
import HostSupport
import OSLog
import SwiftUI
import TypedFullState

@Reducer
public struct SynthsList {

  @ObservableState
  public struct State: Equatable {
    public var rows: IdentifiedArrayOf<SynthButton.State>

    public init(rows: IdentifiedArrayOf<SynthButton.State> = []) {
      self.rows = rows
    }
  }

  public enum Action {
    case addButtonTapped
    case created(instance: SynthInstance)
    case delegate(Delegate)
    case initialize
    case makeInstance
    case rows(IdentifiedActionOf<SynthButton>)
    case playNote
    case startLoops
    case stopLoops

    @CasePathable
    public enum Delegate {
      case added(instance: SynthInstance)
      case removed(instance: SynthInstance)
      case settingsButtonTapped
    }
  }

  public init() {}

  @Dependency(\.componentDescription) var componentDescription

  public var body: some ReducerOf<Self> {

    Reduce { state, action in
      log.action("SynthsList", action)
      switch action {

      case .addButtonTapped: return addButtonTapped(&state)
      case .created(instance: let instance): return created(&state, instance: instance)
      case .delegate: return .none
      case .initialize: return initialize(&state)
      case .makeInstance: return makeInstance(&state)
      case .playNote: return playNote(&state)
      case .rows(.element(id: let id, action: .delegate(let action))): return processRowAction(&state, id: id, action: action)
      case .rows: return .none
      case .startLoops: return startLoops(&state)
      case .stopLoops: return stopLoops(&state)
      }
    }
    .forEach(\.rows, action: \.rows) {
      SynthButton()
    }
  }
}

extension SynthsList {

  private func addButtonTapped(_ state: inout State) -> Effect<Action> {
    log.info("addButtonTapped BEGIN")
    @Shared(.auv3InstanceCount) var auv3InstanceCount
    $auv3InstanceCount.withLock { $0 = auv3InstanceCount + 1 }
    log.info("addButtonTapped - \(auv3InstanceCount)")
    return makeInstance(&state)
  }

  private func created(_ state: inout State, instance: SynthInstance) -> Effect<Action> {
    state.rows.append(.init(instance: instance))
    return .send(.delegate(.added(instance: instance)))
  }

  private func initialize(_ state: inout State) -> Effect<Action> {
    @Shared(.auv3InstanceCount) var auv3InstanceCount
    log.info("initialize BEGIIN - \(auv3InstanceCount)")
    return .concatenate(
      // Remove any existing instances -- for when settings change
      state.rows.elements.map {
        .send(.delegate(.removed(instance: $0.instance)))
      } +
      // Create new instances
      (0..<(auv3InstanceCount - state.rows.count)).map {
        _ in makeInstance(&state)
      }
    )
  }

  private func makeInstance(_ state: inout State) -> Effect<Action> {
    log.info("makeInstance BEGIN")
    return .run { [componentDescription] send in
      let instance = try await SynthInstance.make(component: componentDescription)
      await send(.created(instance: instance))
      log.info("makeInstance END")
    }
  }

  private func playNote(_ state: inout State) -> Effect<Action> {
    @Shared(.activeAUv3) var activeAUv3
    guard let activeAUv3 else { return .none }
    guard let button = state.rows[id: activeAUv3] else { return .none }
    button.instance.audioUnit.auAudioUnit.playNote()
    return .none
  }

  private func startLoops(_ state: inout State) -> Effect<Action> {
    log.info("startLoops BEGIN")
    defer { log.info("startLoops END") }
    return .merge(state.rows.map {
      .send(.rows(.element(id: $0.id, action: .startLoop)))
    })
  }

  private func stopLoops(_ state: inout State) -> Effect<Action> {
    log.info("stopLoops BEGIN")
    defer { log.info("stoptLoops END") }
    return .merge(state.rows.map {
      .send(.rows(.element(id: $0.id, action: .stopLoop)))
    })
  }

  private func processRowAction(
    _ state: inout State,
    id: SynthButton.State.ID,
    action: SynthButton.Action.Delegate
  ) -> Effect<Action> {
    log.action("processRowAction", action)
    switch action {

    case .deleteRequested(id: let id):
      guard let removed = state.rows.remove(id: id) else { return .none }
      @Shared(.activeAUv3) var activeAUv3
      if id == activeAUv3 {
        $activeAUv3.withLock { $0 = state.rows.last?.id }
      }

      @Shared(.auv3InstanceCount) var auv3InstanceCount
      $auv3InstanceCount.withLock { $0 = auv3InstanceCount - 1 }

      log.info("processRowAction END - \(auv3InstanceCount)")
      return .send(.delegate(.removed(instance: removed.instance)))
    }
  }
}

// MARK: - View

public struct AUv3sListView: View {
  @State private var store: StoreOf<SynthsList>

  public init(store: StoreOf<SynthsList>) {
    self.store = store
  }

  public var body: some View {
    VStack {
      HStack {
        Text("AUv3 Instances")
        Spacer()
        Button {
          store.send(.addButtonTapped)
        } label: {
          Image(systemName: "plus")
        }
        Button {
          store.send(.delegate(.settingsButtonTapped))
        } label: {
          Image(systemName: "gear")
        }
      }
      List {
        ForEach(store.scope(state: \.rows, action: \.rows)) {
          AUv3ButtonView(store: $0)
        }
      }
    }
  }
}

#if DEBUG

extension AUv3sListView {

  static var preview: some View {
    prepareDependencies {
      $0.uuid = .incrementing

      @Shared(.auv3InstanceCount) var auv3InstanceCount
      $auv3InstanceCount.withLock { $0 = 3 }

      return VStack {
        AUv3sListView(store: Store(initialState: .init()) { SynthsList() })
      }
    }
  }
}

#Preview {
  AUv3sListView.preview
    .padding()
}

#endif // DEBUG

private let log = Logger(category: "AUv3sList")
