// Copyright © 2025 Brad Howes. All rights reserved.

import AudioUnit
import AVFoundation
import AUv3Controls
import ComposableArchitecture
import Sharing
import SwiftUI

@Reducer
public struct ReverbFeature {

  @ObservableState
  public struct State: Equatable {

    @ObservationStateIgnored
    public var device: ReverbConfig.Draft = .init()
    @ObservationStateIgnored
    public var pending: ReverbConfig.Draft = .init()

    public var enabled: ToggleFeature.State
    public var locked: ToggleFeature.State
    public var wetDryMix: KnobFeature.State

    public var isDirty: Bool {
      pending.enabled != device.enabled ||
      pending.roomPreset != device.roomPreset ||
      pending.wetDryMix != device.wetDryMix
    }

    public init() {
      @Shared(.parameterTree) var parameterTree
      @Shared(.reverbLockEnabled) var lockEnabled
      self.locked = .init(isOn: lockEnabled, displayName: "Lock")
      self.enabled = .init(isOn: false, displayName: "On")
      self.wetDryMix = .init(parameter: parameterTree[.reverbAmount])
    }
  }

  public enum Action {
    case activePresetIdChanged(Preset.ID?)
    case applyConfigForPreset(ReverbConfig.Draft)
    case enabled(ToggleFeature.Action)
    case initialize
    case locked(ToggleFeature.Action)
    case roomPresetChanged(AVAudioUnitReverbPreset)
    case saveDebounced
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
  @Dependency(\.defaultDatabase) private var database
  @Dependency(\.reverbDevice) private var reverbDevice
  @Shared(.activeState) private var activeState
  @Shared(.parameterTree) var parameterTree

  public var body: some ReducerOf<Self> {

    Scope(state: \.enabled, action: \.enabled) { ToggleFeature() }
    Scope(state: \.locked, action: \.locked) { ToggleFeature() }
    Scope(state: \.wetDryMix, action: \.wetDryMix) { KnobFeature(parameter: parameterTree[.reverbAmount]) }

    Reduce { state, action in
      switch action {

      case let .activePresetIdChanged(presetId):
        return activePresetIdChanged(&state, presetId: presetId)

      case let .applyConfigForPreset(config):
        return applyConfigForPreset(&state, config: config)

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
}

extension ReverbFeature {

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

    let newConfig = ReverbConfig.draft(for: presetId)

    if state.isDirty && state.pending.presetId != nil {

      // Protect the existing dirty config
      let toSave = state.pending

      return .merge(

        // We always want a save to finish so it is not cancellable
        .run { _ in
          withDatabaseWriter { db in
            try ReverbConfig.upsert {
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

  private func applyConfigForPreset(_ state: inout State, config: ReverbConfig.Draft) -> Effect<Action> {
    reverbDevice.setConfig(config)
    state.device = config
    state.pending = config
    return .merge(
      reduce(into: &state, action: .enabled(.setValue(state.device.enabled))),
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
      try ReverbConfig.upsert {
        state.device
      }
      .returning(\.self)
      .fetchOneForced(db)
    }

    guard let unwrapped = found else {
      return .none
    }

    let config: ReverbConfig.Draft = .init(unwrapped)
    state.device = config
    state.pending = config

    return .none
  }

  private func updateAndSave<T: BinaryFloatingPoint>(
    _ state: inout State,
    path: WritableKeyPath<ReverbConfig.Draft, T>,
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
    path: WritableKeyPath<ReverbConfig.Draft, T>,
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
    reverbDevice.setConfig(state.device)
    return .none
  }

  private func updateLocked(_ state: inout State) -> Effect<Action> {
    @Shared(.reverbLockEnabled) var lockEnabled
    $lockEnabled.withLock { $0.toggle() }
    return .none
  }
}

public struct ReverbView: View {
  @Bindable private var store: StoreOf<ReverbFeature>
  @Environment(\.auv3ControlsTheme) var theme

  public init(store: StoreOf<ReverbFeature>) {
    self.store = store
  }

  public var body: some View {
    EffectsContainer(
      enabled: store.enabled.isOn,
      title: "Reverb",
      onOff: ToggleView(store: store.scope(state: \.enabled, action: \.enabled)),
      globalLock: ToggleView(store: store.scope(state: \.locked, action: \.locked)) {
        Image(systemName: "lock")
      }
    ) {
      HStack(alignment: .center, spacing: 8) {
        Picker("Room", selection: $store.pending.roomPreset.sending(\.roomPresetChanged)) {
          ForEach(AVAudioUnitReverbPreset.allCases, id: \.self) { room in
            Text(room.name).tag(room)
              .font(theme.font)
              .foregroundStyle(theme.textColor)
          }
        }
        .pickerStyle(.wheel)
        .frame(width: 110)  // !!! Magic size that fits all of the strings without wasted space
        KnobView(store: store.scope(state: \.wetDryMix, action: \.wetDryMix))
      }
    }
    .task { await store.send(.initialize).finish() }
  }
}

extension ReverbView {
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

    prepareDependencies {
      // swiftlint:disable:next force_try
      $0.defaultDatabase = try! appDatabase()
      $0.reverbDevice = .init(setConfig: { print("ReverbDevice.setConfig:", $0) })
    }

    return VStack {
      ScrollView(.horizontal) {
        ReverbView(store: Store(initialState: .init()) { ReverbFeature() })
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
  ReverbView.preview
}
