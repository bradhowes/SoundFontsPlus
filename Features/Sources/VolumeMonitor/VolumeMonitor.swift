// Copyright © 2025 Brad Howes. All rights reserved.

import BaseSupport
import ComposableArchitecture
import Dependencies
import FeatureSupport
import Models
import SwiftToasts
import SwiftUI

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

  @Shared(.activeState) private var activeState

  private enum CancelId {
    case monitorSessionVolume
  }
}

private extension VolumeMonitor {

  func initialize(_ state: inout State) -> Effect<Action> {
    @Dependency(\.outputVolume) var outputVolume
    return .merge(
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
    @Dependency(\.outputVolume) var outputVolume
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
      .task {
        await store.send(.initialize).finish()
      }
  }
}

extension View {
  public func volumeMonitorHUD(store: StoreOf<VolumeMonitor>) -> some View {
    modifier(VolumeMonitorModifier(store: store))
  }
}

struct VolumeMonitorDemoView: View {

  /// A mock of AVAudioSession.outputVolume that toggles between 1.0 and 0.0
  final class OutputVolumeFlipFlop: @unchecked Sendable {
    var continuation: AsyncStream<Float>.Continuation?
    var currentValue: Float = 1.0

    func getValue() -> Float { self.currentValue }

    /**
     Toggle current value and emit onto the stream.

     - returns: new value
     */
    @discardableResult func advance() -> Float {
      self.currentValue = 1.0 - self.currentValue
      continuation?.yield(self.currentValue)
      return self.currentValue
    }

    func startStreaming() -> AsyncStream<Float> {
      AsyncStream<Float> { self.continuation = $0 }
    }

    /**
     Obtain an `OutputVolume` instance that relies on this instance for operation.

     - returns: current value
     */
    func makeOutputVolume() -> OutputVolume {
      .init(
        getValue: { self.getValue() },
        startStreaming: { self.startStreaming() }
      )
    }
  }

  private let volumes: OutputVolumeFlipFlop
  @State private var volume: Float
  @State private var store: StoreOf<VolumeMonitor>
  @Shared(.activeState) var activeState

  init(volumes: OutputVolumeFlipFlop, store: StoreOf<VolumeMonitor>) {
    self.volumes = volumes
    self.store = store
    self.volume = self.volumes.getValue()
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
            let newValue: Preset.ID? = activeState.activePresetId == nil ? Preset.ID(rawValue: 1) : nil
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
  let mockVolume = VolumeMonitorDemoView.OutputVolumeFlipFlop()
  // swiftlint:disable:next redundant_discardable_let
  let _ = prepareDependencies {
    @Shared(.activeState) var activeState
    $activeState.activePresetId.withLock { $0 = Preset.ID(rawValue: 1) }
    $0.outputVolume = mockVolume.makeOutputVolume()
    mockVolume.advance()
  }
  let store: StoreOf<VolumeMonitor> = .init(initialState: VolumeMonitor.State()) { VolumeMonitor() }
  VolumeMonitorDemoView(volumes: mockVolume, store: store)
}
