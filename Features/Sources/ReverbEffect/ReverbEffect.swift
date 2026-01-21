// Copyright © 2025 Brad Howes. All rights reserved.

import AVFAudio.AVAudioUnitReverb
import AUv3Controls
import FeatureSupport

@Reducer
public struct ReverbEffect {

  @ObservableState
  public struct State: Equatable {

    public var config: ReverbConfig.Draft
    public var enabled: ToggleFeature.State
    public var locked: ToggleFeature.State
    public var wetDryMix: KnobFeature.State
    public var dirty: Bool

    public init(presetId: Preset.ID = -1, dirty: Bool = false) {
      @Shared(.parameterTree) var parameterTree
      @Shared(.reverbLockEnabled) var locked
      self.config = .init(presetId: presetId)
      self.locked = .init(isOn: locked, displayName: "Lock")
      self.enabled = .init(isOn: false, displayName: "On")
      self.wetDryMix = .init(parameter: parameterTree[.reverbAmount])

      self.dirty = dirty
    }
  }

  public enum Action {
    case activePresetIdChanged(Preset.ID?)
    case applyConfigForPreset(Preset.ID)
    case deinitialize
    case enabled(ToggleFeature.Action)
    case initialize
    case locked(ToggleFeature.Action)
    case roomPresetChanged(AVAudioUnitReverbPreset)
    case saveDebounced
    case updateDebounced
    case wetDryMix(KnobFeature.Action)
  }

  public init() {}

  public var body: some ReducerOf<Self> {

    Scope(state: \.enabled, action: \.enabled) { ToggleFeature() }
    Scope(state: \.locked, action: \.locked) { ToggleFeature() }
    Scope(state: \.wetDryMix, action: \.wetDryMix) { KnobFeature() }

    Reduce { state, action in
      log.action("ReverbEffect", action)

      switch action {

      case .activePresetIdChanged(let presetId):
        return activePresetIdChanged(&state, presetId: presetId)

      case .applyConfigForPreset(let presetId):
        return applyConfigForPreset(&state, presetId: presetId)

      case .deinitialize:
        if state.dirty {
          _ = saveDebounced(&state)
        }
        return .merge(
          CancelId.allCases.map { .cancel(id: $0) }
        )

      case .enabled:
        return updateAndSave(&state, path: \.enabled, value: state.enabled.isOn)

      case .initialize:
        return monitorActivePresetId()

      case .locked:
        return updateLocked(&state)

      case let .roomPresetChanged(value):
        return updateAndSave(&state, path: \.roomPreset, value: value)

      case .saveDebounced:
        return saveDebounced(&state)

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
  @Dependency(\.reverbDevice) private var reverbDevice
  @Dependency(\.debounceDurations) private var debounceDurations

  private enum CancelId: String, CaseIterable {
    case reverbEffectApplyConfigForPreset
    case reverbEffectMonitorActivePresetId
    case reverbEffectSaveDebouncer
    case reverbEffectUpdateDebouncer
  }
}

extension ReverbEffect {

  private func activePresetIdChanged(_ state: inout State, presetId: Preset.ID?) -> Effect<Action> {
    guard
      !state.locked.isOn,
      let presetId,
      state.config.presetId != presetId
    else {
      return .none
    }

    guard state.dirty else {
      return applyConfigForPreset(&state, presetId: presetId)
    }

    return .merge(
      .run { [toSave = state.config] _ in ReverbConfig.save(config: toSave) },
      .run { send in await send(.applyConfigForPreset(presetId)) }
        .cancellable(id: CancelId.reverbEffectApplyConfigForPreset, cancelInFlight: true)
    )
  }

  private func applyConfigForPreset(_ state: inout State, presetId: Preset.ID) -> Effect<Action> {
    log.info("applyConfigForPreset - \(presetId)")
    let config = ReverbConfig.draft(for: presetId, cloning: state.config)
    log.debug("config: \(String(describing: config), privacy: .public)")
    reverbDevice.setConfig(config)
    state.config = config
    state.dirty = false

    return .merge(
      reduce(into: &state, action: .enabled(.setValue(config.enabled))),
      reduce(into: &state, action: .wetDryMix(.setValue(config.wetDryMix))),
    )
  }

  private func monitorActivePresetId() -> Effect<Action> {
    .publisher {
      $activeState.activePresetId
        .publisher
        .removeDuplicates()
        .map { .activePresetIdChanged($0) }
    }.cancellable(id: CancelId.reverbEffectMonitorActivePresetId, cancelInFlight: true)
  }

  private func runDebouncers(_ state: inout State) -> Effect<Action> {
    state.dirty = true
    return .merge(
      .run { send in
        await send(.updateDebounced)
      }.debounce(
        id: CancelId.reverbEffectUpdateDebouncer,
        for: debounceDurations.effectsDisplayUpdates,
        scheduler: mainQueue
      ),
      .run(priority: .utility) { send in
        await send(.saveDebounced)
      }.debounce(
        id: CancelId.reverbEffectSaveDebouncer,
        for: debounceDurations.effectsConfigurationSaves,
        scheduler: mainQueue
      )
    )
  }

  private func saveDebounced(_ state: inout State) -> Effect<Action> {
    state.dirty = false
    if let presetId = activeState.activePresetId,
       state.config.presetId == presetId,
       let found = ReverbConfig.save(config: state.config) {
      state.config = .init(found)
    }
    return .none
  }

  private func updateAndSave<T: BinaryFloatingPoint>(
    _ state: inout State,
    path: WritableKeyPath<ReverbConfig.Draft, T>,
    value: T
  ) -> Effect<Action> {
    guard abs(state.config[keyPath: path] - value) > 1e-8 else { return .none }
    state.config[keyPath: path] = value
    return runDebouncers(&state)
  }

  private func updateAndSave<T: Equatable>(
    _ state: inout State,
    path: WritableKeyPath<ReverbConfig.Draft, T>,
    value: T
  ) -> Effect<Action> {
    guard state.config[keyPath: path] != value else { return .none }
    state.config[keyPath: path] = value
    return runDebouncers(&state)
  }

  private func updateDebounced(_ state: inout State) -> Effect<Action> {
    reverbDevice.setConfig(state.config)
    return .none
  }

  private func globalToLocalConfig(_ state: inout State) -> Effect<Action> {
    guard let presetId = activeState.activePresetId else { return .none }
    var localConfig = ReverbConfig.draft(for: presetId)
    localConfig.roomPreset = state.config.roomPreset
    localConfig.wetDryMix = state.config.wetDryMix
    localConfig.enabled = state.config.enabled
    state.config = localConfig
    reverbDevice.setConfig(state.config)
    return saveDebounced(&state)
  }

  private func updateLocked(_ state: inout State) -> Effect<Action> {
    @Shared(.reverbLockEnabled) var locked
    $locked.withLock { $0 = state.locked.isOn }
    if !state.locked.isOn && state.config.enabled {
      return globalToLocalConfig(&state)
    }
    return .none
  }
}

public struct ReverbEffectView: View {
  @Bindable private var store: StoreOf<ReverbEffect>
  @Environment(\.auv3ControlsTheme) private var theme

  public init(store: StoreOf<ReverbEffect>) {
    self.store = store
  }

  public var body: some View {
    NamedKnobCollectionContainer(
      enabled: store.enabled.isOn,
      title: "Reverb",
      onOff: ToggleView(store: store.scope(state: \.enabled, action: \.enabled)),
      globalLock: ToggleView(store: store.scope(state: \.locked, action: \.locked)) {
        Image(systemName: "lock")
      }
    ) {
      HStack(alignment: .center, spacing: 8) {
        Picker("Room", selection: $store.config.roomPreset.sending(\.roomPresetChanged)) {
          ForEach(AVAudioUnitReverbPreset.allCases, id: \.self) { room in
            Text(room.name).tag(room)
              .font(theme.font)
              .foregroundStyle(theme.textColor)
          }
        }
#if os(iOS)
        .pickerStyle(.wheel)
        .frame(width: 110)  // !!! Magic size that fits all of the strings without wasted space
#endif
        KnobView(store: store.scope(state: \.wetDryMix, action: \.wetDryMix))
      }
    }
    .task { await store.send(.initialize).finish() }
    .onDisappear { store.send(.deinitialize) }
  }
}

private let log: Logger = .init(category: "ReverbEffect")

#if DEBUG

extension ReverbEffectView {
  static var preview: some View {
    @Shared(.activeState) var activeState = .default

    var theme = Theme()
    theme.controlTrackStrokeStyle = StrokeStyle(lineWidth: 5, lineCap: .round)
    theme.controlValueStrokeStyle = StrokeStyle(lineWidth: 3, lineCap: .round)
    theme.toggleOnIndicatorSystemName = "arrowtriangle.down.fill"
    theme.toggleOffIndicatorSystemName = "arrowtriangle.down"

    prepareDependencies {
      $0.defaultDatabase = previewDatabase()
      var testValue = ReverbDevice.testValue
      testValue.setConfig = { print("ReverbDevice.setConfig:", $0) }
      $0.reverbDevice = testValue
    }

    return VStack {
      ScrollView(.horizontal) {
        ReverbEffectView(store: Store(initialState: .init()) { ReverbEffect() })
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
  ReverbEffectView.preview
}

#endif // DEBUG
