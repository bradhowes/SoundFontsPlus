// Copyright © 2025 Brad Howes. All rights reserved.

#if false

import AudioToolbox
import ComposableArchitecture
import FeatureSupport
import Foundation

/**
 Monitor the state of the silent mode switch. This relies on a "hack" that leverages the fact that playing a system
 sound when silent mode is active will finish much faster than when silent mode is inactive.

 NOTE: kept around for knowledge, but this is not used since the silent mode switch has no effect on audio output from
 the AVAudioEngine.
 */
@Reducer
public struct MuteSwitchMonitor {

  @ObservableState
  public struct State: Equatable {
    public var muted: Bool = false

    public init(muted: Bool = false) {
      self.muted = muted
    }
  }

  public enum Action {
    case deinitialize
    case delegate(Delegate)
    case finishedPlaying(TimeInterval)
    case initialize

    @CasePathable
    public enum Delegate: Equatable {
      case muteChanged(Bool)
    }
  }

  public init() {}

  public var body: some Reducer<State, Action> {

    Reduce { state, action in
      log.info("reduce \(action)")
      switch action {

      case .deinitialize:
        return .cancel(id: CancelId.monitorMuteSwitch)

      case .delegate:
        return .none

      case .finishedPlaying(let duration):
        let muted = duration < 0.1
        if muted != state.muted {
          state.muted = muted
          return .send(.delegate(.muteChanged(state.muted)))
        }
        return .none

      case .initialize:
        return initialize(&state)
      }
    }
  }

  private enum CancelId: String {
    case muteSwitchMonitorMuteSwitch
  }
}

private extension MuteSwitchMonitor {

  private func initialize(_ state: inout State) -> Effect<Action> {
    guard let url = Bundle.module.url(forResource: "mute", withExtension: "aiff") else {
      fatalError("unable to locate mute.aiff audio file")
    }

    var soundId: SystemSoundID = 1
    if unsafe AudioServicesCreateSystemSoundID(url as CFURL, &soundId) == kAudioServicesNoError {
      var respectMuteSwitch: UInt32 = 1
      unsafe AudioServicesSetProperty(
        kAudioServicesPropertyIsUISound,
        UInt32(MemoryLayout.size(ofValue: soundId)),
        &soundId,
        UInt32(MemoryLayout.size(ofValue: respectMuteSwitch)),
        &respectMuteSwitch
      )
      log.info("registered silent audio file")
    } else {
      log.error("Failed to setup silent sound player")
      return .none
    }

    return .run(priority: .utility, name: "monitorMuteSwitch") { [soundId = soundId ] send in
      log.info("running monitor task")
      while !Task.isCancelled {
        let result = await withCheckedContinuation { continuation in
          let start = Date.timeIntervalSinceReferenceDate
          AudioServicesPlaySystemSoundWithCompletion(soundId) {
            continuation.resume(with: .success(start))
          }
        }
        let duration = Date.timeIntervalSinceReferenceDate - result
        log.debug("monitor duration: \(duration)")
        await send(.finishedPlaying(duration))
        try await Task.sleep(for: .seconds(5))
      }
      log.debug("exiting monitor task")
    }.cancellable(id: CancelId.monitorMuteSwitch, cancelInFlight: true)
  }
}

private let log: Logger = .init(category: "VolumeMonitor")

#endif // false
