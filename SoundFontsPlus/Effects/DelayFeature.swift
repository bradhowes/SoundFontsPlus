// Copyright © 2025 Brad Howes. All rights reserved.

import AudioUnit
import AUv3Controls
import ComposableArchitecture
import Sharing
import SwiftUI

@Reducer
public struct DelayFeature {

  @ObservableState
  public struct State: Equatable {

    @ObservationStateIgnored
    public var device: DelayConfig.Draft = .init()
    @ObservationStateIgnored
    public var pending: DelayConfig.Draft = .init()

    public var enabled: ToggleFeature.State
    public var locked: ToggleFeature.State
    public var time: KnobFeature.State
    public var feedback: KnobFeature.State
    public var cutoff: KnobFeature.State
    public var wetDryMix: KnobFeature.State

    public var isDirty: Bool {
      pending.enabled != device.enabled ||
      pending.time != device.time ||
      pending.feedback != device.feedback ||
      pending.cutoff != device.cutoff ||
      pending.wetDryMix != device.wetDryMix
    }

    public init() {
      @Shared(.parameterTree) var parameterTree
      @Shared(.delayLockEnabled) var lockEnabled
      self.locked = .init(isOn: lockEnabled, displayName: "Lock")
      self.enabled = .init(isOn: false, displayName: "On")
      self.time = .init(parameter: parameterTree[.delayTime])
      self.feedback = .init(parameter: parameterTree[.delayFeedback])
      self.cutoff = .init(parameter: parameterTree[.delayCutoff])
      self.wetDryMix = .init(parameter: parameterTree[.delayAmount])
    }
  }

  public enum Action {
    case activePresetIdChanged(Preset.ID?)
    case applyConfigForPreset(DelayConfig.Draft)
    case cutoff(KnobFeature.Action)
    case enabled(ToggleFeature.Action)
    case feedback(KnobFeature.Action)
    case initialize
    case locked(ToggleFeature.Action)
    case saveDebounced
    case time(KnobFeature.Action)
    case updateDebounced
    case wetDryMix(KnobFeature.Action)
  }

  private enum CancelId {
    case applyConfigForPreset
    case monitorActivePresetId
    case saveDebouncer
    case updateDebouncer
  }

  @Dependency(\.mainQueue) var mainQueue
  @Dependency(\.defaultDatabase) var database
  @Dependency(\.delayDevice) var delayDevice
  @Shared(.activeState) var activeState
  @Shared(.parameterTree) var parameterTree

  public var body: some ReducerOf<Self> {

    Scope(state: \.enabled, action: \.enabled) { ToggleFeature() }
    Scope(state: \.locked, action: \.locked) { ToggleFeature() }
    Scope(state: \.time, action: \.time) { KnobFeature(parameter: parameterTree[.delayTime]) }
    Scope(state: \.feedback, action: \.feedback) { KnobFeature(parameter: parameterTree[.delayFeedback]) }
    Scope(state: \.cutoff, action: \.cutoff) { KnobFeature(parameter: parameterTree[.delayCutoff]) }
    Scope(state: \.wetDryMix, action: \.wetDryMix) { KnobFeature(parameter: parameterTree[.delayAmount]) }

    Reduce { state, action in
      switch action {
      case let .activePresetIdChanged(presetId):
        return activePresetIdChanged(&state, presetId: presetId)
      case let .applyConfigForPreset(config):
        return applyConfigForPreset(&state, config: config)
      case .cutoff:
        return updateAndSave(&state, path: \.cutoff, value: state.cutoff.value)
      case .enabled:
        return updateAndSave(&state, path: \.enabled, value: state.enabled.isOn)
      case .feedback:
        return updateAndSave(&state, path: \.feedback, value: state.feedback.value)
      case .initialize:
        return monitorActivePresetId()
      case .locked:
        return updateLocked(&state)
      case .saveDebounced:
        return saveDebounced(&state)
      case .time:
        return updateAndSave(&state, path: \.time, value: state.time.value)
      case .updateDebounced:
        return updateDebounced(&state)
      case .wetDryMix:
        return updateAndSave(&state, path: \.wetDryMix, value: state.wetDryMix.value)
      }
    }
  }
}

extension DelayFeature {

  private func activePresetIdChanged(_ state: inout State, presetId: Preset.ID?) -> Effect<Action> {

    guard !state.locked.isOn else {
      return .none
    }

    guard let presetId else {
      state.pending = state.device
      state.pending.presetId = nil
      return .none
    }

    guard state.pending.presetId != presetId else {
      return .none
    }

    let newConfig = DelayConfig.draft(for: presetId)

    if state.isDirty && state.pending.presetId != nil {

      // Protect the existing dirty config
      let toSave = state.pending

      return .merge(

        // We always want a save to finish so it is not cancellable
        .run { _ in
          withDatabaseWriter { db in
            try DelayConfig.upsert {
              toSave
            }
            .execute(db)
          }
        },

        // With the dirty config protected we can safely execute the following to install the new config.
        // Only let one change be active at a time.
        .run { send in
          await send(.applyConfigForPreset(newConfig))
        }.cancellable(id: CancelId.applyConfigForPreset, cancelInFlight: true)
      )
    }

    // NOTE: it might be safe to run this immmediately if the old preset was not dirty, but there still could be an
    // older task that is waiting to execute. Best approach is to allow TCA to cancel any active task even if it might
    // be slightly slower.
    return .run { send in
      await send(.applyConfigForPreset(newConfig))
    }.cancellable(id: CancelId.applyConfigForPreset, cancelInFlight: true)
  }

  private func applyConfigForPreset(_ state: inout State, config: DelayConfig.Draft) -> Effect<Action> {
    delayDevice.setConfig(config)
    state.device = config
    state.pending = config
    return .merge(
      reduce(into: &state, action: .enabled(.setValue(state.device.enabled))),
      reduce(into: &state, action: .time(.setValue(state.device.time))),
      reduce(into: &state, action: .feedback(.setValue(state.device.feedback))),
      reduce(into: &state, action: .cutoff(.setValue(state.device.cutoff))),
      reduce(into: &state, action: .wetDryMix(.setValue(state.device.wetDryMix))),
    )
  }

  private func monitorActivePresetId() -> Effect<Action> {
    .publisher {
      $activeState.activePresetId
        .publisher
        .map { .activePresetIdChanged($0) }
    }.cancellable(id: CancelId.monitorActivePresetId, cancelInFlight: true)
  }

  private func runDebouncers() -> Effect<Action> {
    .merge(
      .run { send in
        await send(.updateDebounced)
      }.debounce(id: CancelId.updateDebouncer, for: .milliseconds(100), scheduler: mainQueue),
      .run { send in
        await send(.saveDebounced)
      }.debounce(id: CancelId.saveDebouncer, for: .milliseconds(1000), scheduler: mainQueue)
    )
  }

  private func saveDebounced(_ state: inout State) -> Effect<Action> {

    guard state.device.presetId != nil else {
      return .none
    }

    let found = withDatabaseWriter { db in
      try DelayConfig.upsert {
        state.device
      }
      .returning(\.self)
      .fetchOneForced(db)
    }

    guard let unwrapped = found else {
      return .none
    }

    let config: DelayConfig.Draft = .init(unwrapped)
    state.device = config
    state.pending = config

    return .none
  }

  private func updateAndSave<T: BinaryFloatingPoint>(
    _ state: inout State,
    path: WritableKeyPath<DelayConfig.Draft, T>,
    value: T
  ) -> Effect<Action> {

    state.pending[keyPath: path] = value
    if abs(state.device[keyPath: path] - value) < 1e-6 {
      return .none
    }

    state.pending.presetId = activeState.activePresetId

    return runDebouncers()
  }

  private func updateAndSave<T: Equatable>(
    _ state: inout State,
    path: WritableKeyPath<DelayConfig.Draft, T>,
    value: T
  ) -> Effect<Action> {

    state.pending[keyPath: path] = value
    if state.device[keyPath: path] == value {
      return .none
    }

    state.pending.presetId = activeState.activePresetId

    return runDebouncers()
  }

  private func updateDebounced(_ state: inout State) -> Effect<Action> {
    state.device = state.pending
    delayDevice.setConfig(state.device)
    return .none
  }

  private func updateLocked(_ state: inout State) -> Effect<Action> {
    @Shared(.delayLockEnabled) var lockEnabled
    $lockEnabled.withLock { $0.toggle() }
    return .none
  }
}

public struct DelayView: View {
  @Bindable private var store: StoreOf<DelayFeature>

  public init(store: StoreOf<DelayFeature>) {
    self.store = store
  }

  public var body: some View {
    EffectsContainer(
      enabled: store.enabled.isOn,
      title: "Delay",
      onOff: ToggleView(store: store.scope(state: \.enabled, action: \.enabled)),
      globalLock: ToggleView(store: store.scope(state: \.locked, action: \.locked)) {
        Image(systemName: "lock")
      }
    ) {
      HStack(alignment: .center, spacing: 8) {
        KnobView(store: store.scope(state: \.time, action: \.time))
        KnobView(store: store.scope(state: \.feedback, action: \.feedback))
        KnobView(store: store.scope(state: \.cutoff, action: \.cutoff))
        KnobView(store: store.scope(state: \.wetDryMix, action: \.wetDryMix))
      }
    }.task {
      await store.send(.initialize).finish()
    }
  }
}

extension DelayView {
  static var preview: some View {
    @Shared(.activeState) var activeState
    $activeState.withLock {
      $0.activePresetId = 1
    }

    var theme = Theme()
    theme.controlTrackStrokeStyle = StrokeStyle(lineWidth: 5, lineCap: .round)
    theme.controlValueStrokeStyle = StrokeStyle(lineWidth: 3, lineCap: .round)
    theme.toggleOnIndicatorSystemName = "arrowtriangle.down.fill"
    theme.toggleOffIndicatorSystemName = "arrowtriangle.down"

    @Shared(.parameterTree) var parameterTree = ParameterAddress.createParameterTree()

    prepareDependencies {
      // swiftlint:disable:next force_try
      $0.defaultDatabase = try! appDatabase()
      $0.delayDevice = .init(getConfig: {
        DelayConfig.Draft()
      }, setConfig: {
        print("DelayDevice.setConfig:", $0)
      })
    }

    return VStack {
      ScrollView(.horizontal) {
        DelayView(store: Store(initialState: .init()) {
          DelayFeature()
        })
        .environment(\.auv3ControlsTheme, theme)
      }
      .padding()
      .border(theme.controlBackgroundColor, width: 1)
      Button("Preset 1") {
        $activeState.withLock {
          $0.activePresetId = 1
        }
      }
      Button("Preset 2") {
        $activeState.withLock {
          $0.activePresetId = 2
        }
      }
    }
  }
}

#Preview {
  DelayView.preview
}
