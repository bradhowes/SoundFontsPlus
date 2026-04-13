// Copyright © 2025 Brad Howes. All rights reserved.

@preconcurrency import AudioToolbox
import AUv3Controls
import ComposableArchitecture
import Foundation
import HostSupport
import SwiftUI
import TypedFullState

@Reducer
public struct SynthButton {

  @ObservableState
  public struct State: Equatable, Identifiable {
    public typealias ID = SynthInstance.ID
    public var instance: SynthInstance
    public var displayName: String
    public var id: ID { instance.id }

    public init(instance: SynthInstance) {
      self.instance = instance
      self.displayName = instance.name
    }
  }

  @Shared(.activeAUv3) var activeAUv3

  public enum Action {
    case activateButtonTapped
    case deinitialize
    case delegate(Delegate)
    case initialize
    case playNote
    case startLoop
    case stateChanged
    case stopLoop

    @CasePathable
    public enum Delegate {
      case deleteRequested(id: State.ID)
    }
  }

  public var body: some ReducerOf<Self> {
    Reduce { state, action in
      log.info("reduce \(action)")
      switch action {
      case .activateButtonTapped: return activateButtonTapped(&state)
      case .deinitialize: return .merge(CancelId.allCases.map { .cancel(id: $0) })
      case .delegate: return .none
      case .initialize: return monitorCurrentPreset(&state)
      case .playNote: return playNote(&state)
      case .startLoop: return startLoop(&state)
      case .stateChanged: return stateChanged(&state)
      case .stopLoop: return stopLoop(&state)
      }
    }
  }

  private enum CancelId: String, CaseIterable {
    case auv3ButtonMonitorAllParameterValues
    case auv3ButtonMonitorCurrentPreset
  }
}

extension SynthButton {

  private func activateButtonTapped(_ state: inout State) -> Effect<Action> {
    state.displayName = state.instance.name
    $activeAUv3.withLock { $0 = state.id }
    return .none
  }

  private func monitorCurrentPreset(_ state: inout State) -> Effect<Action> {
    log.info("monitorCurrentPreset BEGIN")
    return .run { [audioUnit = state.instance.audioUnit.auAudioUnit] send in
      await audioUnit.propertyValueStream(for: \.currentPreset) {
        await send(.stateChanged)
      }
      log.info("monitorCurrentPreset END")
    }.cancellable(id: CancelId.auv3ButtonMonitorCurrentPreset)
  }

  private func monitorAllParameterValues(_ state: inout State) -> Effect<Action> {
    log.info("monitorAllParameterValues BEGIN")
    return .run { [audioUnit = state.instance.audioUnit.auAudioUnit] send in
      await audioUnit.propertyValueStream(for: \.allParameterValues) {
        await send(.stateChanged)
      }
      log.info("monitorAllParameterValues END")
    }.cancellable(id: CancelId.auv3ButtonMonitorAllParameterValues)
  }

  private func playNote(_ state: inout State) -> Effect<Action> {
    state.instance.audioUnit.auAudioUnit.playNote()
    return .none
  }

  private func startLoop(_ state: inout State) -> Effect<Action> {
    .run { [audioUnit = state.instance.audioUnit.auAudioUnit] send in
      await audioUnit.playLoop()
    }.cancellable(id: state.instance.id)
  }

  private func stateChanged(_ state: inout State) -> Effect<Action> {
    state.displayName = state.instance.audioUnit.auAudioUnit.audioUnitShortName ?? "N/A"
    return .none
  }

  private func stopLoop(_ state: inout State) -> Effect<Action> {
    .cancel(id: state.instance.id)
  }
}

public struct AUv3ButtonView: View {
  @State private var store: StoreOf<SynthButton>
  @Shared(.activeAUv3) var activeAUv3

  public init(store: StoreOf<SynthButton>) {
    self.store = store
  }

  public var body: some View {
    HStack {
      Button {
        store.send(.activateButtonTapped)
      } label: {
        Text(store.displayName)
          .animation(.smooth, value: store.displayName)
      }
      Spacer()
      if store.id == activeAUv3 {
        Image(systemName: "checkmark")
      }
    }
    .swipeActions(edge: .trailing, allowsFullSwipe: false) {
      Button {
        store.send(.delegate(.deleteRequested(id: store.id)))
      } label: {
        Image(systemName: "trash")
          .tint(.red)
      }
    }
    .task {
      await store.send(.initialize).finish()
    }
  }
}

#if DEBUG

extension AUv3ButtonView {

  static var preview: some View {
    prepareDependencies {
      $0.uuid = .incrementing
      $0.componentDescription = .previewValue

      @Dependency(\.uuid) var uuid
      @Dependency(\.componentDescription) var componentDescription

      return VStack {
        List {
          AsyncModel { instance in
            AUv3ButtonView(
              store: Store(
                initialState: .init(
                  instance: instance
                )
              ) {
                SynthButton()
              }
            )
          } model: {
            try await SynthInstance.make(component: componentDescription)
          }
          AsyncModel { instance in
            AUv3ButtonView(
              store: Store(
                initialState: .init(
                  instance: instance
                )
              ) {
                SynthButton()
              }
            )
          } model: {
            try await SynthInstance.make(component: componentDescription)
          }
        }
      }
    }
  }
}

#Preview("buttons") {
  AUv3ButtonView.preview
}

#endif // DEBUG

private let log = Logger(category: "AUv3Button")
