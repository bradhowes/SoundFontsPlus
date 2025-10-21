// Copyright © 2025 Brad Howes. All rights reserved.

import FeatureSupport
import SwiftToasts

private let log = Logger(category: "VolumeMonitor")

@Reducer
public struct VolumeMonitor {

  public enum Reason : Sendable{
    case volumeLevelIsZero
    case noActivePreset
  }

  @ObservableState
  public struct State: Equatable {
    var reason: Reason?

    public init(reason: Reason? = nil) {
      self.reason = reason
    }
  }

  public enum Action: BindableAction {
    case activePresetIdChanged(Preset.ID?)
    case binding(BindingAction<State>)
    case delegate(Delegate)
    case initialize
    case deinitialize
    case volumeChanged(Float)

    public enum Delegate {
      case mutedVolume(Reason?)
    }
  }

  public init() {}

  public var body: some Reducer<State, Action> {
    BindingReducer()

    Reduce { state, action in
      switch action {

      case .binding:
        return .none

      case .deinitialize:
        return .cancel(id: CancelId.monitorSessionVolume)

      case .initialize:
        return initialize(&state)

      case .activePresetIdChanged(let presetId):
        return presetChanged(&state, presetId: presetId)

      case .delegate:
        return .none

      case .volumeChanged(let volume):
        return volumeChanged(&state, volume: volume)
      }
    }
  }

  @Dependency(\.outputVolume) var outputVolume
  @Shared(.activeState) private var activeState

  private enum CancelId {
    case monitorSessionVolume
  }
}

private extension VolumeMonitor {

  func initialize(_ state: inout State) -> Effect<Action> {
    .merge(
      volumeChanged(&state, volume: outputVolume.getValue()),
      monitorOutputVolume(&state)
    )
  }

  func monitorOutputVolume(_ state: inout State) -> Effect<Action> {
    .run { send in
      while !Task.isCancelled {
        @Dependency(\.outputVolume) var outputVolume
        for await value in outputVolume.startStreaming() {
          await send(.volumeChanged(value))
        }
        log.info("stopped observing volume")
      }
    }.cancellable(id: CancelId.monitorSessionVolume, cancelInFlight: true)
  }

  func presetChanged(_ state: inout State, presetId: Preset.ID?) -> Effect<Action> {
    return updateReason(&state, volume: outputVolume.getValue(), presetId: presetId)
  }

  func updateReason(_ state: inout State, volume: Float, presetId: Preset.ID?) -> Effect<Action> {
    let newReason: Reason? = switch (volume > 0, presetId != nil) {
    case (true, true): nil
    case (false, true): .volumeLevelIsZero
    case (true, false): .noActivePreset
    case (false, false): state.reason
    }

    if newReason != state.reason {
      state.reason = newReason
      return .send(.delegate(.mutedVolume(state.reason)))
    }

    return .none
  }

  func volumeChanged(_ state: inout State, volume: Float) -> Effect<Action> {
    log.info("volumeChanged \(volume)")
    return updateReason(&state, volume: volume, presetId: activeState.activePresetId)
  }
}

public struct VolumeMonitorModifier: ViewModifier {
  @Bindable private var store: StoreOf<VolumeMonitor>

  public init(store: StoreOf<VolumeMonitor>) {
    self.store = store
  }

  public func body(content: Content) -> some View {
    content
      .onAppear {
        store.send(.initialize)
      }
      .toast(
        item: $store.reason,
        alignment: .top
      ) { reason in
        if reason == .volumeLevelIsZero {
          Toast(role: .failure, duration: .indefinite) {
            Label {
              Text("Volume is muted.")
            } icon: {
              Image(systemName: "speaker.slash")
            }
          }
        } else if reason == .noActivePreset {
          Toast(role: .failure, duration: .indefinite) {
            Label {
              Text("No preset selected.")
            } icon: {
              Image(systemName: "speaker.slash")
            }
          }
        }
      }
      .toastStyle(.plain)
    // .toastTransition(.scale)
      .toastPresentationInvalidation(.all)
      .toastInteractiveDismissDisabled(false)
  }
}

extension View {
  public func volumeMonitorHUD(store: StoreOf<VolumeMonitor>) -> some View {
    modifier(VolumeMonitorModifier(store: store))
  }
}
//
//#Preview {
//  let mockVolume = OutputVolumeFlipFlop()
//  // swiftlint:disable:next redundant_discardable_let
//  let _ = prepareDependencies {
//    @Shared(.activeState) var activeState
//    $activeState.activePresetId.withLock { $0 = Preset.ID(rawValue: 1) }
//    $0.outputVolume = mockVolume.makeOutputVolume()
//    mockVolume.advance()
//  }
//  let store: StoreOf<VolumeMonitor> = .init(initialState: VolumeMonitor.State()) { VolumeMonitor() }
//  VolumeMonitorDemoView(volumes: mockVolume, store: store)
//}
