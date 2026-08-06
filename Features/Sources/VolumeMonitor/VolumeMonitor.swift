// Copyright © 2025 Brad Howes. All rights reserved.

public import CasePaths
public import ComposableArchitecture
public import FeatureSupport

/**
 Monitor the volume setting for the active audio session. When the volume setting is zero or the active preset ID is
 nil, show a toast image indicating that there will be no audio output and the reason why.
 */
@Reducer
public struct VolumeMonitor {

  @frozen
  public enum Reason: Equatable {
    case volumeLevelIsZero
    case noActivePreset
  }

  @ObservableState
  public struct State: Equatable {
    public var reason: Reason?
    public var activePresetId: Preset.ID?

    public init(reason: Reason? = nil, activePresetId: Preset.ID? = nil) {
      self.reason = reason
      self.activePresetId = activePresetId
    }
  }

  public enum Action {
    case activePresetIdChanged(Preset.ID?)
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

  public var body: some Reducer<State, Action> {

    Reduce { state, action in
      log.action("VolumeMonitor", action)
      return switch action {
      case .activePresetIdChanged(let presetId): presetChanged(&state, presetId: presetId)
      case .delegate: .none
      case .start: start(&state)
      case .stop: .cancel(id: CancelId.volumeMonitorMonitorSessionVolume)
      case .volumeChanged(let volume): volumeChanged(&state, volume: volume)
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
    return .run(priority: .utility, name: "monitorOutputVolume") { [outputVolume] send in
      defer { log.info("monitorOuptutVolume stopped") }
      while !Task.isCancelled {
        for await value in outputVolume.startStreaming() {
          if Task.isCancelled { break }
          await send(.volumeChanged(value))
        }
        log.info("stopped observing volume")
      }
    }.cancellable(id: CancelId.volumeMonitorMonitorSessionVolume, cancelInFlight: true)
  }

  func presetChanged(_ state: inout State, presetId: Preset.ID?) -> Effect<Action> {
    state.activePresetId = presetId
    return updateReason(
      &state,
      volume: outputVolume.getValue(),
      presetId: presetId
    )
  }

  func start(_ state: inout State) -> Effect<Action> {
    log.info("start")
    return .merge(
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
      presetId: state.activePresetId
    )
  }
}

private let log: Logger = .init(category: "VolumeMonitor")
