// Copyright © 2025 Brad Howes. All rights reserved.

import FeatureSupport
import SwiftToasts

#if os(iOS)

/**
 Monitor the volume setting for the active audio session. When the volume setting is zero or the active preset ID is
 nil, show a toast image indicating that there will be no audio output and the reason why.
 */
@Reducer
public struct VolumeMonitor {

  public enum Reason: Sendable {
    case volumeLevelIsZero
    case noActivePreset
  }

  @ObservableState
  public struct State: Equatable {
    public var reason: Reason?

    public init(reason: Reason? = nil) {
      self.reason = reason
    }
  }

  public enum Action: BindableAction {
    case activePresetIdChanged(Preset.ID?)
    case binding(BindingAction<State>)
    case delegate(Delegate)
    case start
    case stop
    case volumeChanged(Float)

  @CasePathable
    public enum Delegate: Equatable {
      case reasonChanged(Reason?)
    }
  }

  public init() {}

  @Dependency(\.outputVolume) private var outputVolume
  @Shared(.activeState) private var activeState

  public var body: some Reducer<State, Action> {
    BindingReducer()

    Reduce { state, action in
      log.info("reduce \(action)")
      switch action {

      case .activePresetIdChanged(let presetId):
        return presetChanged(&state, presetId: presetId)

      case .binding:
        return .none

      case .stop:
        return .cancel(id: CancelId.volumeMonitorMonitorSessionVolume)

      case .delegate:
        return .none

      case .start:
        return start(&state)

      case .volumeChanged(let volume):
        return volumeChanged(&state, volume: volume)
      }
    }
  }

  private enum CancelId: String {
    case volumeMonitorMonitorSessionVolume
  }
}

private extension VolumeMonitor {

  func monitorOutputVolume(_ state: inout State) -> Effect<Action> {
    log.info("monitorOutputVolume")
    return .run(priority: .utility, name: "monitorOutputVolume") { send in
      while !Task.isCancelled {
        @Dependency(\.outputVolume) var outputVolume
        for await value in outputVolume.startStreaming() {
          if Task.isCancelled { break }
          await send(.volumeChanged(value))
        }
        log.info("stopped observing volume")
      }
    }.cancellable(id: CancelId.volumeMonitorMonitorSessionVolume, cancelInFlight: true)
  }

  func presetChanged(_ state: inout State, presetId: Preset.ID?) -> Effect<Action> {
    return updateReason(
      &state,
      volume: outputVolume.getValue(),
      presetId: presetId
    )
  }

  func start(_ state: inout State) -> Effect<Action> {
    .merge(
      volumeChanged(&state, volume: outputVolume.getValue()),
      monitorOutputVolume(&state)
    )
  }

  func updateReason(_ state: inout State, volume: Float, presetId: Preset.ID?) -> Effect<Action> {
    let newReason: Reason? = switch (volume > 0, presetId != nil) {
    case (true, true): nil
    case (false, true): .volumeLevelIsZero
    case (true, false): .noActivePreset
    case (false, false): state.reason
    }

    log.info("newReason: \(newReason.debugDescription)")

    if newReason != state.reason {
      state.reason = newReason
      return .send(.delegate(.reasonChanged(state.reason)))
    }

    return .none
  }

  func volumeChanged(_ state: inout State, volume: Float) -> Effect<Action> {
    log.info("volumeChanged \(volume)")
    return updateReason(
      &state,
      volume: volume,
      presetId: activeState.activePresetId
    )
  }
}

public struct VolumeMonitorModifier: ViewModifier {
  @Bindable private var store: StoreOf<VolumeMonitor>

  public init(store: StoreOf<VolumeMonitor>) {
    self.store = store
  }

  public func body(content: Content) -> some View {
    content
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
      .toastPresentationInvalidation(.all)
      .toastInteractiveDismissDisabled(false)
  }
}

extension View {
  public func volumeMonitorHUD(store: StoreOf<VolumeMonitor>) -> some View {
    modifier(VolumeMonitorModifier(store: store))
  }
}

private let log = Logger(category: "VolumeMonitor")

#endif
