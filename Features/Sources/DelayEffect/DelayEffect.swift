// Copyright © 2025 Brad Howes. All rights reserved.

import AUv3Controls
import FeatureSupport

@Reducer
public struct DelayEffect {
  public static let unsetPresetId: Preset.ID = -1

  @ObservableState
  public struct State: Equatable {

    public var config: DelayConfig.Draft
    public var enabled: ToggleFeature.State
    public var locked: ToggleFeature.State
    public var time: KnobFeature.State
    public var feedback: KnobFeature.State
    public var cutoff: KnobFeature.State
    public var wetDryMix: KnobFeature.State
    public var dirty: Bool

    public init(presetId: Preset.ID = DelayEffect.unsetPresetId, dirty: Bool = false) {
      @Shared(.parameterTree) var parameterTree
      @Shared(.delayLockEnabled) var locked
      self.config = .init(presetId: presetId)
      self.locked = .init(isOn: locked, displayName: "Lock")
      self.enabled = .init(isOn: false, displayName: "On")
      self.time = .init(parameter: parameterTree[.delayTime])
      self.feedback = .init(parameter: parameterTree[.delayFeedback])
      self.cutoff = .init(parameter: parameterTree[.delayCutoff])
      self.wetDryMix = .init(parameter: parameterTree[.delayAmount])
      self.dirty = dirty
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
    Scope(state: \.time, action: \.time) { KnobFeature() }
    Scope(state: \.feedback, action: \.feedback) { KnobFeature() }
    Scope(state: \.cutoff, action: \.cutoff) { KnobFeature() }
    Scope(state: \.wetDryMix, action: \.wetDryMix) { KnobFeature() }

    Reduce { state, action in

      log.action("DelayEffect", action)

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
  @Dependency(\.debounceDurations) private var debounceDurations

  private enum CancelId: String, CaseIterable {
    case delayEffectApplyConfigForPreset
    case delayEffectMonitorActivePresetId
    case delayEffectSaveDebouncer
    case delayEffectUpdateDebouncer
  }
}

extension DelayEffect {

  private func activePresetIdChanged(_ state: inout State, presetId: Preset.ID?) -> Effect<Action> {
    // Nothing to do?
    guard
      !state.locked.isOn,
      let presetId,
      state.config.presetId != presetId
    else {
      return .none
    }

    // Nothing to save?
    guard
      state.config.presetId != Self.unsetPresetId,
      state.dirty
    else {
      return applyConfigForPreset(&state, presetId: presetId)
    }

    // Save current changes and then apply new config. Order is important here.
    return .concatenate(
      .run { [toSave = state.config] _ in DelayConfig.save(config: toSave) },
      .run { send in await send(.applyConfigForPreset(presetId)) }
        .cancellable(id: CancelId.delayEffectApplyConfigForPreset, cancelInFlight: true)
    )
  }

  private func applyConfigForPreset(_ state: inout State, presetId: Preset.ID) -> Effect<Action> {
    log.info("applyConfigForPreset - \(presetId)")
    let config = DelayConfig.draft(for: presetId, cloning: state.config)
    log.debug("config: \(String(describing: config), privacy: .public)")
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
    .run { [$activeState] send in
      for await value in UncheckedSendable($activeState.activePresetId.publisher.values.removeDuplicates()) {
        await send(.activePresetIdChanged(value))
      }
    }.cancellable(id: CancelId.delayEffectMonitorActivePresetId, cancelInFlight: true)
  }

  private func runDebouncers(_ state: inout State) -> Effect<Action> {
    state.dirty = true
    return .merge(
      .run { send in
        await send(.updateDebounced)
      }.debounce(
        id: CancelId.delayEffectUpdateDebouncer,
        for: debounceDurations.effectsDisplayUpdates,
        scheduler: mainQueue
      ),
      .run(priority: .utility) { send in
        await send(.saveDebounced)
      }.debounce(
        id: CancelId.delayEffectSaveDebouncer,
        for: debounceDurations.effectsConfigurationSaves,
        scheduler: mainQueue
      )
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
    NamedKnobCollectionContainer(
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

private let log: Logger = .init(category: "DelayEffect")

#if DEBUG

extension DelayEffectView {
  // swiftlint:disable:next function_body_length
  static func preview(presetId: Preset.ID) -> some View {
    @Shared(.activeState) var activeState
    $activeState.withLock {
      $0.activePresetId = presetId
    }

    var theme = Theme()
    theme.controlTrackStrokeStyle = StrokeStyle(lineWidth: 5, lineCap: .round)
    theme.controlValueStrokeStyle = StrokeStyle(lineWidth: 3, lineCap: .round)
    theme.toggleOnIndicatorSystemName = "arrowtriangle.down.fill"
    theme.toggleOffIndicatorSystemName = "arrowtriangle.down"

    @Shared(.parameterTree) var parameterTree = ParameterAddress.createParameterTree()

    prepareDependencies {
      // swiftlint:disable:next force_try
      $0.defaultDatabase = try! appDatabase { db in
        try DelayConfig.insert {
          DelayConfig.Draft(
            time: 0.5,
            feedback: 80,
            cutoff: 8000.0,
            wetDryMix: 50.0,
            enabled: true,
            presetId: 1
          )
        }
        .execute(db)
        try DelayConfig.insert {
          DelayConfig.Draft(
            time: 1.0,
            feedback: -70,
            cutoff: 12000.0,
            wetDryMix: 100.0,
            enabled: true,
            presetId: 2
          )
        }
        .execute(db)
        try DelayConfig.insert {
          DelayConfig.Draft(
            time: 1.5,
            feedback: 0,
            cutoff: 3000.0,
            wetDryMix: 25.0,
            enabled: false,
            presetId: 3
          )
        }
        .execute(db)
      }

      var testValue = DelayDevice.testValue
      testValue.setConfig = { print("DelayDevice.setConfig:", $0) }
      $0.delayDevice = testValue
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
      Button("Preset 3") {
        $activeState.withLock {
          $0.activePresetId = 3
        }
      }
    }
  }
}

#Preview {
  DelayEffectView.preview(presetId: 2)
}

#endif // DEBUG
