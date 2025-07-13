// Copyright © 2025 Brad Howes. All rights reserved.

import AudioUnit
import AUv3Controls
import ComposableArchitecture
import Sharing
import SwiftUI

@Reducer
public struct DelayFeature {
  let parameters: AUParameterTree

  public init(parameters: AUParameterTree) {
    self.parameters = parameters
  }

  public var state: State { .init(parameters: self.parameters) }

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

    public init(parameters: AUParameterTree) {
      @Shared(.delayLockEnabled) var lockEnabled
      self.locked = .init(isOn: lockEnabled, displayName: "Lock")
      self.enabled = .init(isOn: false, displayName: "On")
      self.time = .init(parameter: parameters[.delayTime])
      self.feedback = .init(parameter: parameters[.delayFeedback])
      self.cutoff = .init(parameter: parameters[.delayCutoff])
      self.wetDryMix = .init(parameter: parameters[.delayAmount])
    }
  }

  public enum Action {
    case activePresetIdChanged(Preset.ID?)
    case cutoff(KnobFeature.Action)
    case debouncedSave
    case debouncedUpdate
    case enabled(ToggleFeature.Action)
    case feedback(KnobFeature.Action)
    case locked(ToggleFeature.Action)
    case task
    case time(KnobFeature.Action)
    case wetDryMix(KnobFeature.Action)
  }

  private enum CancelId {
    case debouncedSave
    case debouncedUpdate
    case monitorActivePresetId
  }

  @Dependency(\.mainQueue) var mainQueue
  @Dependency(\.defaultDatabase) var database
  @Dependency(\.delayDevice) var delayDevice
  @Shared(.activeState) var activeState

  public var body: some ReducerOf<Self> {

    Scope(state: \.enabled, action: \.enabled) { ToggleFeature() }
    Scope(state: \.locked, action: \.locked) { ToggleFeature() }
    Scope(state: \.time, action: \.time) { KnobFeature(parameter: parameters[.delayTime]) }
    Scope(state: \.feedback, action: \.feedback) { KnobFeature(parameter: parameters[.delayFeedback]) }
    Scope(state: \.cutoff, action: \.cutoff) { KnobFeature(parameter: parameters[.delayCutoff]) }
    Scope(state: \.wetDryMix, action: \.wetDryMix) { KnobFeature(parameter: parameters[.delayAmount]) }

    Reduce { state, action in
      switch action {
      case let .activePresetIdChanged(presetId): return activePresetIdChanged(&state, presetId: presetId)
      case .debouncedSave: return save(&state)
      case .debouncedUpdate: return update(&state)
      case .enabled: return updateAndSave(&state, path: \.enabled, value: state.enabled.isOn)
      case .locked: return updateLocked(&state)
      case .task: return monitorActivePresetId()
      case .time: return updateAndSave(&state, path: \.time, value: state.time.value)
      case .feedback: return updateAndSave(&state, path: \.feedback, value: state.feedback.value)
      case .cutoff: return updateAndSave(&state, path: \.cutoff, value: state.cutoff.value)
      case .wetDryMix: return updateAndSave(&state, path: \.wetDryMix, value: state.wetDryMix.value)
      }
    }
  }
}

extension DelayFeature {

  private func activePresetIdChanged(_ state: inout State, presetId: Preset.ID?) -> Effect<Action> {

    print("activePresetIdChanged: \(String(describing: presetId))")

    guard !state.locked.isOn else {
      print("locked: \(String(describing: presetId))")
      return .none
    }

    guard let presetId else {
      print("nil presetId")
      state.pending = state.device
      state.pending.presetId = nil
      return .none
    }

    guard state.pending.presetId != presetId else {
      print("same presetId")
      return .none
    }

    if state.isDirty && state.pending.presetId != nil {
      print("saving \(state.pending)")
      withDatabaseWriter { db in
        try DelayConfig.upsert {
          state.pending
        }
        .execute(db)
      }
    }

    let config = DelayConfig.draft(for: presetId)
    print("loaded \(config)")
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

  private func updateAndSave<T: BinaryFloatingPoint>(
    _ state: inout State,
    path: WritableKeyPath<DelayConfig.Draft, T>,
    value: T
  ) -> Effect<Action> {

    state.pending[keyPath: path] = value
    if abs(state.device[keyPath: path] - value) < 1e-6 {
      print("no change in \(path)")
      return .none
    }

    print("setting presetId due to change in \(path)")
    state.pending.presetId = activeState.activePresetId

    return .merge(
      .run { send in
        await send(.debouncedUpdate)
      }.debounce(id: CancelId.debouncedUpdate, for: .milliseconds(100), scheduler: mainQueue),
      .run { send in
        await send(.debouncedSave)
      }.debounce(id: CancelId.debouncedSave, for: .milliseconds(1000), scheduler: mainQueue)
    )
  }

  private func updateAndSave<T: Equatable>(
    _ state: inout State,
    path: WritableKeyPath<DelayConfig.Draft, T>,
    value: T
  ) -> Effect<Action> {

    state.pending[keyPath: path] = value
    if state.device[keyPath: path] == value {
      print("no change in \(path)")
      return .none
    }

    print("setting presetId due to change in \(path)")
    state.pending.presetId = activeState.activePresetId

    return .merge(
      .run { send in
        await send(.debouncedUpdate)
      }.debounce(id: CancelId.debouncedUpdate, for: .milliseconds(100), scheduler: mainQueue),
      .run { send in
        await send(.debouncedSave)
      }.debounce(id: CancelId.debouncedSave, for: .milliseconds(1000), scheduler: mainQueue)
    )
  }

  private func save(_ state: inout State) -> Effect<Action> {

    guard state.device.presetId != nil else {
      print("save - skipping nil presetId")
      return .none
    }

    print("save")

    let found = withDatabaseWriter { db in
      try DelayConfig.upsert {
        state.device
      }
      .returning(\.self)
      .fetchOneForced(db)
    }

    guard let unwrapped = found else {
      print("skipping unwrapped nil")
      return .none
    }

    let config: DelayConfig.Draft = .init(unwrapped)
    state.device = config
    state.pending = config

    print("upsert: ", state.device)

    return .none
  }

  private func update(_ state: inout State) -> Effect<Action> {
    state.device = state.pending
    delayDevice.setConfig(state.device)
    return .none
  }

  private func monitorActivePresetId() -> Effect<Action> {
    .publisher {
      $activeState.activePresetId.publisher.map { Action.activePresetIdChanged($0) }
    }.cancellable(id: CancelId.monitorActivePresetId, cancelInFlight: true)
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
      await store.send(.task).finish()
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

    let parameterTree = ParameterAddress.createParameterTree()
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
        DelayView(store: Store(initialState: .init(parameters: parameterTree)) {
          DelayFeature(parameters: parameterTree)
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
