// Copyright © 2025 Brad Howes. All rights reserved.

import AVKit
import ComposableArchitecture
import ProgressHUD
import SwiftUI

private let log = Logger(category: "VolumeMonitor")

@Reducer
public struct VolumeMonitorFeature {

  public enum Reason {
    /// Volume level is at zero
    case volumeLevel
    /// There is no preset active in the synth
    case noPreset
  }

  @ObservableState
  public struct State: Equatable {
    var noVolumeReason: Reason?

    @ObservationStateIgnored
    var observerToken: NSKeyValueObservation?
  }

  public enum Action {
    case activePresetIdChanged(Preset.ID?)
    case delegate(Delegate)
    case initialize
    case volumeChanged(Float)

    public enum Delegate {
      case noVolumeReasonChanged(Reason?)
    }
  }

  @Shared(.activeState) var activeState

  public var body: some Reducer<State, Action> {
    Reduce { state, action in
      switch action {
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

  private enum CancelId {
    case monitorActivePresetId
    case monitorSessionVolume
  }
}

private extension VolumeMonitorFeature {

  func initialize(_ state: inout State) -> Effect<Action> {
    monitorSessionVolume(&state)
  }

  func monitorSessionVolume(_ state: inout State) -> Effect<Action> {
    let stream: AsyncStream<Float>
    (state.observerToken, stream) = AVAudioSession.sharedInstance().startObservingOutputVolume()
    return .run { send in
      for await value in stream {
        await send(.volumeChanged(value))
      }
    }.cancellable(id: CancelId.monitorSessionVolume, cancelInFlight: true)
  }

  func presetChanged(_ state: inout State, presetId: Preset.ID?) -> Effect<Action> {
    updateReason(&state, volume: AVAudioSession.sharedInstance().outputVolume, presetId: presetId)
  }

  func updateReason(_ state: inout State, volume: Float, presetId: Preset.ID?) -> Effect<Action> {
    if volume < 0.01 {
      state.noVolumeReason = .volumeLevel
    } else if presetId == nil {
      state.noVolumeReason = .noPreset
    } else {
      state.noVolumeReason = .none
    }

    return .send(.delegate(.noVolumeReasonChanged(state.noVolumeReason)))
  }

  func volumeChanged(_ state: inout State, volume: Float) -> Effect<Action> {
    updateReason(&state, volume: volume, presetId: activeState.activePresetId)
  }
}

public struct VolumeMonitorModifier: ViewModifier {
  private var store: StoreOf<VolumeMonitorFeature>

  public init(store: StoreOf<VolumeMonitorFeature>) {
    self.store = store
  }

  public func body(content: Content) -> some View {
    content
      .task {
        await store.send(.initialize).finish()
      }
      .onChange(of: store.noVolumeReason) {
        switch store.noVolumeReason {
        case .volumeLevel:
          ProgressHUD.colorBanner = .systemRed
          ProgressHUD.banner("Volume", "Volume set to 0.", delay: 120.0)

        case .noPreset:
          ProgressHUD.colorBanner = .systemRed
          ProgressHUD.banner("Preset", "No active preset.", delay: 120.0)

        case .none:
          ProgressHUD.bannerHide()
        }
      }
  }
}

extension View {
  public func volumeMonitorHUD(store: StoreOf<VolumeMonitorFeature>) -> some View {
    modifier(VolumeMonitorModifier(store: store))
  }
}
