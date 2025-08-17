// Copyright © 2025 Brad Howes. All rights reserved.

import AUv3Controls
import ComposableArchitecture
import Sharing
import SwiftUI

@Reducer
public struct DelayFeature {

  @ObservableState
  public struct State: Equatable {

    @ObservationStateIgnored
    public var config: DelayConfig.Draft = .init(presetId: -1)

    public var enabled: ToggleFeature.State
    public var locked: ToggleFeature.State
    public var time: KnobFeature.State
    public var feedback: KnobFeature.State
    public var cutoff: KnobFeature.State
    public var wetDryMix: KnobFeature.State
    public var dirty: Bool = false

    public init() {
      @Shared(.parameterTree) var parameterTree
      @Shared(.delayLockEnabled) var locked
      self.locked = .init(isOn: locked, displayName: "Lock")
      self.enabled = .init(isOn: false, displayName: "On")
      self.time = .init(parameter: parameterTree[.delayTime])
      self.feedback = .init(parameter: parameterTree[.delayFeedback])
      self.cutoff = .init(parameter: parameterTree[.delayCutoff])
      self.wetDryMix = .init(parameter: parameterTree[.delayAmount])
    }
  }

  public enum Action {
    case activePresetIdChanged
    case applyConfigForPreset
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

  @Shared(.activeState) var activeState
  @Shared(.parameterTree) var parameterTree

  @Dependency(\.defaultDatabase) var database
  @Dependency(\.delayDevice) var delayDevice
  @Dependency(\.mainQueue) var mainQueue

  public var body: some ReducerOf<Self> {

    Scope(state: \.enabled, action: \.enabled) { ToggleFeature() }
    Scope(state: \.locked, action: \.locked) { ToggleFeature() }
    Scope(state: \.time, action: \.time) { KnobFeature(parameter: parameterTree[.delayTime]) }
    Scope(state: \.feedback, action: \.feedback) { KnobFeature(parameter: parameterTree[.delayFeedback]) }
    Scope(state: \.cutoff, action: \.cutoff) { KnobFeature(parameter: parameterTree[.delayCutoff]) }
    Scope(state: \.wetDryMix, action: \.wetDryMix) { KnobFeature(parameter: parameterTree[.delayAmount]) }

    Reduce { state, action in
      switch action {

      case .activePresetIdChanged:
        return activePresetIdChanged(&state)

      case .applyConfigForPreset:
        return applyConfigForPreset(&state)

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

  private func activePresetIdChanged(_ state: inout State) -> Effect<Action> {

    guard
      !state.locked.isOn,
      let presetId = activeState.activePresetId,
      state.config.presetId != presetId
    else {
      return .none
    }

    if state.dirty {
      let toSave = state.config
      return .merge(
        .run { _ in
          withDatabaseWriter { db in
            try DelayConfig.upsert {
              toSave
            }
            .execute(db)
          }
        },
        .run { send in
          await send(.applyConfigForPreset)
        }.cancellable(id: CancelId.applyConfigForPreset, cancelInFlight: true)
      )
    }

    return .run { send in
      await send(.applyConfigForPreset)
    }.cancellable(id: CancelId.applyConfigForPreset, cancelInFlight: true)
  }

  private func applyConfigForPreset(_ state: inout State) -> Effect<Action> {
    guard let presetId = activeState.activePresetId else {
      return .none
    }

    // If this preset does not have a delay config, assume the current settings.
    let config = DelayConfig.draft(for: presetId, cloning: state.config)
    delayDevice.setConfig(config)
    state.config = config
    state.dirty = false

    return .merge(
      reduce(into: &state, action: .enabled(.setValue(config.enabled))),
      reduce(into: &state, action: .time(.setValue(config.time))),
      reduce(into: &state, action: .feedback(.setValue(config.feedback))),
      reduce(into: &state, action: .cutoff(.setValue(config.cutoff))),
      reduce(into: &state, action: .wetDryMix(.setValue(config.wetDryMix))),
    )
  }

  private func monitorActivePresetId() -> Effect<Action> {
    .publisher {
      $activeState.activePresetId
        .publisher
        .map { _ in .activePresetIdChanged }
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
    guard let presetId = activeState.activePresetId else {
      return .none
    }

    guard state.config.presetId == presetId else {
      return .none
    }

    let found = withDatabaseWriter { db in
      try DelayConfig.upsert {
        state.config
      }
      .returning(\.self)
      .fetchOneForced(db)
    }

    // Update the draft with the info returned from upsert
    guard let unwrapped = found else { return .none }
    state.config = .init(unwrapped)

    return .none
  }

  private func updateAndSave<T: BinaryFloatingPoint>(
    _ state: inout State,
    path: WritableKeyPath<DelayConfig.Draft, T>,
    value: T
  ) -> Effect<Action> {
    guard abs(state.config[keyPath: path] - value) > 1e-8 else { return .none }
    state.config[keyPath: path] = value
    state.dirty = true
    return runDebouncers()
  }

  private func updateAndSave<T: Equatable>(
    _ state: inout State,
    path: WritableKeyPath<DelayConfig.Draft, T>,
    value: T
  ) -> Effect<Action> {
    guard state.config[keyPath: path] != value else { return .none }
    state.config[keyPath: path] = value
    state.dirty = true
    return runDebouncers()
  }

  private func updateDebounced(_ state: inout State) -> Effect<Action> {
    delayDevice.setConfig(state.config)
    return .none
  }

  private func globalToLocalConfig(_ state: inout State) -> Effect<Action> {
    guard let presetId = activeState.activePresetId else { return .none }
    var localConfig = DelayConfig.draft(for: presetId)
    localConfig.time = state.config.time
    localConfig.feedback = state.config.feedback
    localConfig.cutoff = state.config.cutoff
    localConfig.wetDryMix = state.config.wetDryMix
    localConfig.enabled = state.config.enabled
    state.config = localConfig
    delayDevice.setConfig(state.config)
    return saveDebounced(&state)
  }

  private func updateLocked(_ state: inout State) -> Effect<Action> {
    @Shared(.delayLockEnabled) var locked
    $locked.withLock { $0 = state.locked.isOn }
    if !state.locked.isOn && state.config.enabled {
      return globalToLocalConfig(&state)
    }
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
      $0.delayDevice = .init(setConfig: { print("DelayDevice.setConfig:", $0) })
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
