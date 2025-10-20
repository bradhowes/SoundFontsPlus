// Copyright © 2025 Brad Howes. All rights reserved.

import AUv3Controls
import ComposableArchitecture
import Dependencies
import FeatureSupport
import Models
import Sharing
import SwiftUI
import Tagged

@Reducer
public struct DelayEffect {

  @ObservableState
  public struct State: Equatable {

    @ObservationStateIgnored
    var config: DelayConfig.Draft
    var enabled: ToggleFeature.State
    var locked: ToggleFeature.State
    var time: KnobFeature.State
    var feedback: KnobFeature.State
    var cutoff: KnobFeature.State
    var wetDryMix: KnobFeature.State
    var dirty: Bool = false

    public init(presetId: Preset.ID = -1) {
      @Shared(.parameterTree) var parameterTree
      @Shared(.delayLockEnabled) var locked
      self.config = .init(presetId: presetId)
      self.locked = .init(isOn: locked, displayName: "Lock")
      self.enabled = .init(isOn: false, displayName: "On")
      self.time = .init(parameter: parameterTree[.delayTime])
      self.feedback = .init(parameter: parameterTree[.delayFeedback])
      self.cutoff = .init(parameter: parameterTree[.delayCutoff])
      self.wetDryMix = .init(parameter: parameterTree[.delayAmount])
    }
  }

  public enum Action {
    case activePresetIdChanged(Preset.ID?)
    case applyConfigForPreset(Preset.ID)
    case cutoff(KnobFeature.Action)
    case deinitialize
    case enabled(ToggleFeature.Action)
    case feedback(KnobFeature.Action)
    case initialize
    case locked(ToggleFeature.Action)
    case saveDebounced
    case time(KnobFeature.Action)
    case updateDebounced
    case wetDryMix(KnobFeature.Action)
  }

  public init() {}

  public var body: some ReducerOf<Self> {

    Scope(state: \.enabled, action: \.enabled) { ToggleFeature() }
    Scope(state: \.locked, action: \.locked) { ToggleFeature() }
    Scope(state: \.time, action: \.time) { KnobFeature(parameter: parameterTree[.delayTime]) }
    Scope(state: \.feedback, action: \.feedback) { KnobFeature(parameter: parameterTree[.delayFeedback]) }
    Scope(state: \.cutoff, action: \.cutoff) { KnobFeature(parameter: parameterTree[.delayCutoff]) }
    Scope(state: \.wetDryMix, action: \.wetDryMix) { KnobFeature(parameter: parameterTree[.delayAmount]) }

    Reduce { state, action in
      switch action {

      case .activePresetIdChanged(let presetId):
        return activePresetIdChanged(&state, presetId: presetId)

      case .applyConfigForPreset(let presetId):
        return applyConfigForPreset(&state, presetId: presetId)

      case .cutoff:
        return updateAndSave(&state, path: \.cutoff, value: state.cutoff.value)

      case .deinitialize:
        if state.dirty {
          _ = saveDebounced(&state)
        }
        return .merge(CancelId.allCases.map { .cancel(id: $0) })

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

  @Shared(.activeState) private var activeState
  @Shared(.parameterTree) private var parameterTree
  @Dependency(\.mainQueue) private var mainQueue
  @Dependency(\.delayDevice) private var delayDevice

  private enum CancelId: CaseIterable {
    case applyConfigForPreset
    case monitorActivePresetId
    case saveDebouncer
    case updateDebouncer
  }

  private var updateDebounceDuration: DispatchQueue.SchedulerTimeType.Stride { .milliseconds(100) }
  private var saveDebounceDuration: DispatchQueue.SchedulerTimeType.Stride { .milliseconds(1000) }
}

extension DelayEffect {

  private func activePresetIdChanged(_ state: inout State, presetId: Preset.ID?) -> Effect<Action> {
    guard
      !state.locked.isOn,
      let presetId,
      state.config.presetId != presetId
    else {
      return .none
    }

    if state.dirty {
      let toSave = state.config
      return .merge(
        .run { _ in
          DelayConfig.save(config: toSave)
        },
        .run { send in
          await send(.applyConfigForPreset(presetId))
        }.cancellable(id: CancelId.applyConfigForPreset, cancelInFlight: true)
      )
    }

    return .run { send in
      await send(.applyConfigForPreset(presetId))
    }.cancellable(id: CancelId.applyConfigForPreset, cancelInFlight: true)
  }

  private func applyConfigForPreset(_ state: inout State, presetId: Preset.ID) -> Effect<Action> {
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
        .removeDuplicates()
        .map { .activePresetIdChanged($0) }
    }.cancellable(id: CancelId.monitorActivePresetId, cancelInFlight: true)
  }

  private func runDebouncers(_ state: inout State) -> Effect<Action> {
    state.dirty = true
    return .merge(
      .run { send in
        await send(.updateDebounced)
      }.debounce(id: CancelId.updateDebouncer, for: updateDebounceDuration, scheduler: mainQueue),
      .run { send in
        await send(.saveDebounced)
      }.debounce(id: CancelId.saveDebouncer, for: saveDebounceDuration, scheduler: mainQueue)
    )
  }

  private func saveDebounced(_ state: inout State) -> Effect<Action> {
    state.dirty = false
    if let presetId = activeState.activePresetId,
       state.config.presetId == presetId,
       let found = DelayConfig.save(config: state.config) {
      state.config = .init(found)
    }
    return .none
  }

  private func updateAndSave<T: BinaryFloatingPoint>(
    _ state: inout State,
    path: WritableKeyPath<DelayConfig.Draft, T>,
    value: T
  ) -> Effect<Action> {
    guard abs(state.config[keyPath: path] - value) > 1e-8 else { return .none }
    state.config[keyPath: path] = value
    return runDebouncers(&state)
  }

  private func updateAndSave<T: Equatable>(
    _ state: inout State,
    path: WritableKeyPath<DelayConfig.Draft, T>,
    value: T
  ) -> Effect<Action> {
    guard state.config[keyPath: path] != value else { return .none }
    state.config[keyPath: path] = value
    return runDebouncers(&state)
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

public struct DelayEffectView: View {
  @Bindable private var store: StoreOf<DelayEffect>

  public init(store: StoreOf<DelayEffect>) {
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

extension DelayEffectView {
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
        DelayEffectView(store: Store(initialState: .init()) {
          DelayEffect()
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
  DelayEffectView.preview
}
