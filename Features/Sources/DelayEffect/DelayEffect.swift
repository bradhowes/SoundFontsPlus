// Copyright © 2025 Brad Howes. All rights reserved.

import AUv3Controls
import FeatureSupport

@Reducer
public struct DelayEffect {
  public static let unsetPresetId: Preset.ID = -1

  @ObservableState
  public struct State: Equatable {
    public var activePresetId: Preset.ID?
    public var config: DelayConfig.Draft
    public var enabled: ToggleFeature.State
    public var locked: ToggleFeature.State
    public var time: KnobFeature.State
    public var feedback: KnobFeature.State
    public var cutoff: KnobFeature.State
    public var wetDryMix: KnobFeature.State
    public var dirty: Bool

    public init(
      presetId: Preset.ID = DelayEffect.unsetPresetId,
      dirty: Bool = false,
      activePresetId: Preset.ID? = nil
    ) {
      @Shared(.delayLockEnabled) var locked

      let config = DelayConfig.draft(for: presetId)
      log.debug("config: \(config)")

      self.config = config
      self.locked = .init(isOn: locked, displayName: "Lock")
      self.enabled = .init(isOn: config.enabled, displayName: "On")
      self.time = .init(
        value: config.time,
        displayName: "Time",
        minimumValue: 0.0,
        maximumValue: 2.0,
        logarithmic: true
      )
      self.feedback = .init(
        value: config.feedback,
        displayName: "Feedback",
        minimumValue: -100.0,
        maximumValue: 100.0,
        logarithmic: false
      )
      self.cutoff = .init(
        value: config.cutoff,
        displayName: "Cutoff",
        minimumValue: 10.0,
        maximumValue: 20_000.0,
        logarithmic: true
      )
      self.wetDryMix = .init(
        value: config.wetDryMix,
        displayName: "Amount",
        minimumValue: 0.0,
        maximumValue: 100.0,
        logarithmic: false
      )
      self.dirty = dirty
      self.activePresetId = activePresetId

      @Dependency(\.delayDevice) var delayDevice
      delayDevice.setConfig(config)
    }
  }

  public enum Action {
    case activePresetIdChanged(Preset.ID?)
    case applyConfigForPreset(Preset.ID)
    case cutoff(KnobFeature.Action)
    case deinitialize
    case enabled(ToggleFeature.Action)
    case feedback(KnobFeature.Action)
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

  @Dependency(\.mainQueue) private var mainQueue
  @Dependency(\.delayDevice) private var delayDevice
  @Dependency(\.debounceDurations) private var debounceDurations

  private enum CancelId: String, CaseIterable {
    case delayEffectApplyConfigForPreset
    case delayEffectSaveDebouncer
    case delayEffectUpdateDebouncer
  }
}

extension DelayEffect {

  private func activePresetIdChanged(_ state: inout State, presetId: Preset.ID?) -> Effect<Action> {
    log.info("activePresetIdChanged BEGIN")

    // Nothing to do?
    guard
      !state.locked.isOn,
      let presetId,
      state.config.presetId != presetId
    else {
      log.info("activePresetIdChanged END - nothing to do")
      return .none
    }

    // Nothing to save?
    guard
      state.config.presetId != Self.unsetPresetId,
      state.dirty
    else {
      log.info("activePresetIdChanged END - nothing to save")
      return applyConfigForPreset(&state, presetId: presetId)
    }

    log.info("activePresetIdChanged END - saving")
    // Save current changes and then apply new config. Order is important here.
    return .concatenate(
      .run { [toSave = state.config] _ in DelayConfig.save(config: toSave) },
      .run { send in await send(.applyConfigForPreset(presetId)) }
        .cancellable(id: CancelId.delayEffectApplyConfigForPreset, cancelInFlight: true)
    )
  }

  private func applyConfigForPreset(_ state: inout State, presetId: Preset.ID) -> Effect<Action> {
    log.info("applyConfigForPreset BEGIN - \(presetId)")
    let now = state.config
    log.debug("applyConfigForPreset - now: \(now)")
    let new = DelayConfig.draft(for: presetId, cloning: now)
    log.debug("applyConfigForPreset - new: \(new)")

    state.dirty = false

    let changed: Bool = (
      now.enabled != new.enabled ||
      now.time != new.time ||
      now.feedback != new.feedback ||
      now.cutoff != new.cutoff ||
      now.wetDryMix != new.wetDryMix
    )

    if changed {
      state.config = new
      delayDevice.setConfig(new)
    }

    defer { state.activePresetId = presetId }

    if state.activePresetId == nil {
      return .merge(
        reduce(into: &state, action: .enabled(.setValue(new.enabled))),
        reduce(into: &state, action: .time(.setValueSilently(new.time))),
        reduce(into: &state, action: .feedback(.setValueSilently(new.feedback))),
        reduce(into: &state, action: .cutoff(.setValueSilently(new.cutoff))),
        reduce(into: &state, action: .wetDryMix(.setValueSilently(new.wetDryMix))),
      )
    } else if changed {
      return .merge(
        reduce(into: &state, action: .enabled(.setValue(new.enabled))),
        reduce(into: &state, action: .time(.setValue(new.time))),
        reduce(into: &state, action: .feedback(.setValue(new.feedback))),
        reduce(into: &state, action: .cutoff(.setValue(new.cutoff))),
        reduce(into: &state, action: .wetDryMix(.setValue(new.wetDryMix))),
      )
    }

    return .none
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
    if let presetId = state.activePresetId,
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
    guard
      let presetId = state.activePresetId,
      abs(state.config[keyPath: path] - value) > 1e-8
    else {
      return .none
    }
    state.config.presetId = presetId
    state.config[keyPath: path] = value
    let config = state.config
    log.info("updateAndSave - \(config, privacy: .public)")
    return runDebouncers(&state)
  }

  private func updateAndSave<T: Equatable>(
    _ state: inout State,
    path: WritableKeyPath<DelayConfig.Draft, T>,
    value: T
  ) -> Effect<Action> {
    guard
      let presetId = state.activePresetId,
      state.config[keyPath: path] != value
    else {
      return .none
    }
    state.config.presetId = presetId
    state.config[keyPath: path] = value
    let config = state.config
    log.info("updateAndSave - \(config, privacy: .public)")
    return runDebouncers(&state)
  }

  private func updateDebounced(_ state: inout State) -> Effect<Action> {
    delayDevice.setConfig(state.config)
    return .none
  }

  private func globalToLocalConfig(_ state: inout State) -> Effect<Action> {
    guard let presetId = state.activePresetId else { return .none }
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
    }
  }
}

private let log: Logger = .init(category: "DelayEffect")

#if DEBUG

extension DelayEffectView {
  // swiftlint:disable:next function_body_length
  static func preview(presetId: Preset.ID) -> some View {
    var theme = Theme()
    theme.controlTrackStrokeStyle = StrokeStyle(lineWidth: 5, lineCap: .round)
    theme.controlValueStrokeStyle = StrokeStyle(lineWidth: 3, lineCap: .round)
    theme.toggleOnIndicatorSystemName = "arrowtriangle.down.fill"
    theme.toggleOffIndicatorSystemName = "arrowtriangle.down"

    prepareDependencies {
      installApplicationFont()
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

    let store = Store(initialState: .init()) {
      DelayEffect()
    }

    return VStack {
      ScrollView(.horizontal) {
        DelayEffectView(store: store)
          .environment(\.auv3ControlsTheme, theme)
      }
      .padding()
      .border(theme.controlBackgroundColor, width: 1)
      Button("Preset 1") {
        store.send(.activePresetIdChanged(1))
      }
      Button("Preset 2") {
        store.send(.activePresetIdChanged(2))
      }
      Button("Preset 3") {
        store.send(.activePresetIdChanged(3))
      }
    }
  }
}

#Preview {
  DelayEffectView.preview(presetId: 2)
}

#endif // DEBUG
