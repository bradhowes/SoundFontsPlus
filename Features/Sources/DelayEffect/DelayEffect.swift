// Copyright © 2025 Brad Howes. All rights reserved.

public import AUv3Controls
public import CasePaths
public import ComposableArchitecture
import FeatureSupport
public import Models
import SQLiteData
public import SwiftUI
public import Tagged

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

  @Dependency(\.continuousClock) var clock
  @Dependency(\.mainQueue) private var mainQueue
  @Dependency(\.delayDevice) private var delayDevice
  @Dependency(\.debounceDurations) private var debounceDurations

  public var body: some ReducerOf<Self> {

    Scope(state: \.enabled, action: \.enabled) { ToggleFeature() }
    Scope(state: \.locked, action: \.locked) { ToggleFeature() }
    Scope(state: \.time, action: \.time) { KnobFeature() }
    Scope(state: \.feedback, action: \.feedback) { KnobFeature() }
    Scope(state: \.cutoff, action: \.cutoff) { KnobFeature() }
    Scope(state: \.wetDryMix, action: \.wetDryMix) { KnobFeature() }

    Reduce { state, action in
      log.action("DelayEffect", action)
      return switch action {
      case .activePresetIdChanged(let presetId): activePresetIdChanged(&state, presetId: presetId)
      case .applyConfigForPreset(let presetId): applyConfigForPreset(&state, presetId: presetId)
      case .cutoff: updateAndSave(&state, path: \.cutoff, value: state.cutoff.value)
      case .deinitialize: deinitialize(&state)
      case .enabled: updateAndSave(&state, path: \.enabled, value: state.enabled.isOn)
      case .feedback: updateAndSave(&state, path: \.feedback, value: state.feedback.value)
      case .locked: updateLocked(&state)
      case .saveDebounced: saveDebounced(&state)
      case .time: updateAndSave(&state, path: \.time, value: state.time.value)
      case .updateDebounced: updateDebounced(&state)
      case .wetDryMix: updateAndSave(&state, path: \.wetDryMix, value: state.wetDryMix.value)
      }
    }
  }

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
    // Save current changes and then apply new config. Order is important here. We do not want the `save` to be cancelled or else
    // we could lose changes made by the user. We do allow cancelling the `applyConfigForPreset` since we only care about the last
    // call.
    return .concatenate(
      .run { [toSave = state.config] _ in
        DelayConfig.save(config: toSave)
      },
      .run { send in
        await send(.applyConfigForPreset(presetId))
      }.cancellable(id: CancelId.delayEffectApplyConfigForPreset, cancelInFlight: true)
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
        .send(.enabled(.setValue(new.enabled))),
        .send(.time(.setValueSilently(new.time))),
        .send(.feedback(.setValueSilently(new.feedback))),
        .send(.cutoff(.setValueSilently(new.cutoff))),
        .send(.wetDryMix(.setValueSilently(new.wetDryMix))),
      )
    } else if changed {
      return .merge(
        .send(.enabled(.setValue(new.enabled))),
        .send(.time(.setValue(new.time))),
        .send(.feedback(.setValue(new.feedback))),
        .send(.cutoff(.setValue(new.cutoff))),
        .send(.wetDryMix(.setValue(new.wetDryMix))),
      )
    }

    return .none
  }

  private func deinitialize(_ state: inout State) -> Effect<Action> {
    if state.dirty { saveDebounced(&state) }
    return .merge(CancelId.allCases.map { .cancel(id: $0) })
  }

  private func runDebouncers(_ state: inout State) -> Effect<Action> {
    state.dirty = true
    let debounceDurations = self.debounceDurations
    return .merge(
      .run { [clock] send in
        defer { log.info("delayEffectUpdateDebouncer exit") }
        try await clock.sleep(for: debounceDurations.effectsDisplayUpdates)
        if Task.isCancelled { return }
        await send(.updateDebounced)
      }.cancellable(id: CancelId.delayEffectUpdateDebouncer, cancelInFlight: true),
      .run(priority: .utility) { [clock] send in
        defer { log.info("delayEffectSaveDebouncer exit") }
        try await clock.sleep(for: debounceDurations.effectsConfigurationSaves)
        if Task.isCancelled { return }
        await send(.saveDebounced)
      }.cancellable(id: CancelId.delayEffectSaveDebouncer, cancelInFlight: true)
    )
  }

  @discardableResult
  private func saveDebounced(_ state: inout State) -> Effect<Action> {
    log.info("saveDebounced BEGIN")
    state.dirty = false
    if let presetId = state.activePresetId,
       state.config.presetId == presetId,
       let found = DelayConfig.save(config: state.config) {
      state.config = .init(found)
    }
    log.info("saveDebounced END")
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
    log.info("updateDebounced BEGIN")
    delayDevice.setConfig(state.config)
    log.info("updateDebounced END")
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
  @Environment(\.controlSpacing) var controlSpacing

  public init(store: StoreOf<DelayEffect>) {
    self.store = store
  }

  public var body: some View {
    NamedKnobCollectionContainer(
      enabled: store.enabled.isOn,
      title: "Delay",
      onOff: OnOff(store: store),
      globalLock: GlobalLock(store: store)
    ) {
      HStack(alignment: .center, spacing: controlSpacing) {
        KnobView(store: store.scope(state: \.time, action: \.time))
          .helpInfoViewTag(.delayTime)
        KnobView(store: store.scope(state: \.feedback, action: \.feedback))
          .helpInfoViewTag(.delayFeedback)
        KnobView(store: store.scope(state: \.cutoff, action: \.cutoff))
          .helpInfoViewTag(.delayCutoff)
        KnobView(store: store.scope(state: \.wetDryMix, action: \.wetDryMix))
          .helpInfoViewTag(.delayAmount)
      }
    }
  }
}

private struct OnOff: View {
  @State var store: StoreOf<DelayEffect>

  var body: some View {
    ToggleView(store: store.scope(state: \.enabled, action: \.enabled))
      .helpInfoViewTag(.delayOn)
  }
}

private struct GlobalLock: View {
  @State var store: StoreOf<DelayEffect>

  var body: some View {
    ToggleView(store: store.scope(state: \.locked, action: \.locked)) {
      Image(systemName: .effectsLockButtonImageName)
    }
    .helpInfoViewTag(.delayLock)
  }
}

private let log: Logger = .init(category: "DelayEffect")

#if DEBUG

extension DelayEffectView {
  static func preview(presetId: Preset.ID) -> some View {
    installApplicationFont()

    var theme = Theme()
    theme.font = .effectsControl
    theme.controlTrackStrokeStyle = StrokeStyle(lineWidth: 5, lineCap: .round)
    theme.controlValueStrokeStyle = StrokeStyle(lineWidth: 3, lineCap: .round)
    theme.toggleOnIndicatorSystemName = .effectsToggleOnButtonImageName
    theme.toggleOffIndicatorSystemName = .effectsToggleOffButtonImageName

    let store = Store(initialState: .init()) { DelayEffect() }

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
  // swiftlint:disable:next redundant_discardable_let
  let _ = prepareDependencies {
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

    $0.delayDevice = .init(effect: nil, setConfig: { print("DelayDevice.setConfig:", $1) })
  }

  DelayEffectView.preview(presetId: 2)
}

#endif // DEBUG
