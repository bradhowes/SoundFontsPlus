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
    public var config: ReverbConfig.Draft = .init(presetId: -1)

    public var enabled: ToggleFeature.State
    public var locked: ToggleFeature.State
    public var wetDryMix: KnobFeature.State

    public var dirty: Bool = false

    public init() {
      @Shared(.parameterTree) var parameterTree
      @Shared(.reverbLockEnabled) var locked
      self.locked = .init(isOn: locked, displayName: "Lock")
      self.enabled = .init(isOn: false, displayName: "On")
      self.wetDryMix = .init(parameter: parameterTree[.reverbAmount])
    }
  }

  public enum Action {
    case activePresetIdChanged(Preset.ID?)
    case applyConfigForPreset
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

      case .applyConfigForPreset:
        return applyConfigForPreset(&state)

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
            try ReverbConfig.upsert {
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

    let config = ReverbConfig.draft(for: presetId, cloning: state.config)
    reverbDevice.setConfig(config)
    state.config = config

    return .merge(
      reduce(into: &state, action: .enabled(.setValue(config.enabled))),
      reduce(into: &state, action: .wetDryMix(.setValue(config.wetDryMix))),
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

    guard let presetId = activeState.activePresetId else {
      return .none
    }

    guard state.config.presetId == presetId else {
      return .none
    }

    let found = withDatabaseWriter { db in
      try ReverbConfig.upsert {
        state.config
      }
      .returning(\.self)
      .fetchOneForced(db)
    }

    // Update the draft with the info returned from the upsert
    guard let unwrapped = found else { return .none }
    state.config = .init(unwrapped)

    return .none
  }

  private func updateAndSave<T: BinaryFloatingPoint>(
    _ state: inout State,
    path: WritableKeyPath<ReverbConfig.Draft, T>,
    value: T
  ) -> Effect<Action> {
    guard abs(state.config[keyPath: path] - value) > 1e-8 else { return .none }
    state.config[keyPath: path] = value
    state.dirty = true
    return runDebouncers()
  }

  private func updateAndSave<T: Equatable>(
    _ state: inout State,
    path: WritableKeyPath<ReverbConfig.Draft, T>,
    value: T
  ) -> Effect<Action> {
    guard state.config[keyPath: path] != value else { return .none }
    state.config[keyPath: path] = value
    state.dirty = true
    return runDebouncers()
  }

  private func updateDebounced(_ state: inout State) -> Effect<Action> {
    reverbDevice.setConfig(state.config)
    return .none
  }

  private func globalToLocalConfig(_ state: inout State) -> Effect<Action> {
    guard let presetId = activeState.activePresetId else { return .none }
    var localConfig = ReverbConfig.draft(for: presetId)
    localConfig.copy(state.config)
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
        Picker("Room", selection: $store.config.roomPreset.sending(\.roomPresetChanged)) {
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
