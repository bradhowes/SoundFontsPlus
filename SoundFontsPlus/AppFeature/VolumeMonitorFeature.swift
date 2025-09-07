// Copyright © 2025 Brad Howes. All rights reserved.

import ComposableArchitecture
import Dependencies
import ProgressHUD
import SwiftUI

private let log = Logger(category: "VolumeMonitor")

@Reducer
public struct VolumeMonitorFeature {

  public enum Reason {
    case volumeLevelIsZero
    case noActivePreset
  }

  @ObservableState
  public struct State: Equatable {
    var noVolumeReason: Reason?
  }

  public enum Action {
    case activePresetIdChanged(Preset.ID?)
    case delegate(Delegate)
    case initialize
    case deinitialize
    case volumeChanged(Float)

    public enum Delegate {
      case mutedVolume(Reason?)
    }
  }

  @Shared(.activeState) var activeState

  public var body: some Reducer<State, Action> {
    Reduce { state, action in
      switch action {
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

  private enum CancelId {
    case monitorSessionVolume
  }
}

private extension VolumeMonitorFeature {

  func initialize(_ state: inout State) -> Effect<Action> {
    return .run { send in
      while !Task.isCancelled {
        let observerToken: NSKeyValueObservation?
        let stream: AsyncStream<Float>
        @Dependency(\.outputVolume) var outputVolume
        (observerToken, stream) = outputVolume.startObserving()
        log.info("started observing volume")
        for await value in stream {
          await send(.volumeChanged(value))
        }
        log.info("stopped observing volume")
      }
    }.cancellable(id: CancelId.monitorSessionVolume, cancelInFlight: true)
  }

  func presetChanged(_ state: inout State, presetId: Preset.ID?) -> Effect<Action> {
    @Dependency(\.outputVolume) var outputVolume
    return updateReason(&state, volume: outputVolume.getValue(), presetId: presetId)
  }

  func updateReason(_ state: inout State, volume: Float, presetId: Preset.ID?) -> Effect<Action> {
    let newReason: Reason? = switch (volume > 0, presetId != nil) {
    case (true, true): nil
    case (false, true): .volumeLevelIsZero
    case (true, false): .noActivePreset
    case (false, false): state.noVolumeReason
    }

    if newReason != state.noVolumeReason {
      state.noVolumeReason = newReason
      return .send(.delegate(.mutedVolume(state.noVolumeReason)))
    }

    return .none
  }

  func volumeChanged(_ state: inout State, volume: Float) -> Effect<Action> {
    log.info("volumeChanged \(volume)")
    return updateReason(&state, volume: volume, presetId: activeState.activePresetId)
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
        case .volumeLevelIsZero:
          ProgressHUD.colorBanner = .systemRed
          ProgressHUD.banner("Volume", "Volume set to 0.", delay: 120.0)

        case .noActivePreset:
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

struct VolumeMonitorDemoView: View {
  private let volumes: OutputVolumeFlipFlop
  @State private var volume: Float
  @State private var store: StoreOf<VolumeMonitorFeature>
  @Shared(.activeState) var activeState

  init(volumes: OutputVolumeFlipFlop, store: StoreOf<VolumeMonitorFeature>) {
    self.volumes = volumes
    self.store = store
    self.volume = self.volumes.getValue()
    $activeState.activePresetId.withLock { $0 = Preset.ID(rawValue: 1) }
  }

  var body: some View {
    VStack(spacing: 20) {
      Text("Volume: \(volume)")
      Text("Preset ID: \(String(describing: activeState.activePresetId))")
        .volumeMonitorHUD(store: store)
      HStack {
        Button {
          Task {
            volume = volumes.advance()
          }
        } label: {
          Text("Toggle Volume")
        }
        Button {
          Task {
            let newValue: Preset.ID?
            if activeState.activePresetId == nil {
              newValue = Preset.ID(rawValue: 1)
            } else {
              newValue = nil
            }
            store.send(.activePresetIdChanged(newValue))
            $activeState.activePresetId.withLock { $0 = newValue }
          }

        } label: {
          Text("Toggle PresetId")
        }
      }
    }
  }
}

#Preview {
  let volumes = OutputVolumeFlipFlop()
  // swiftlint:disable:next redundant_discardable_let
  let _ = prepareDependencies { $0.outputVolume = volumes.outputVolume() }
  let store: StoreOf<VolumeMonitorFeature> = .init(initialState: VolumeMonitorFeature.State()) {
    VolumeMonitorFeature()
  }
  VolumeMonitorDemoView(volumes: volumes, store: store)
}
