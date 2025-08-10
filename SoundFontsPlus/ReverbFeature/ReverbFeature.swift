// Copyright © 2025 Brad Howes. All rights reserved.

import AudioUnit
import AVFoundation
import AUv3Controls
import ComposableArchitecture
import Sharing
import SwiftUI

@Reducer
public struct ReverbFeature {
  let parameters: AUParameterTree

  public init(parameters: AUParameterTree) {
    self.parameters = parameters
  }

  public var state: State { .init(parameters: self.parameters) }

  @ObservableState
  public struct State: Equatable {

    @ObservationStateIgnored
    public var device: ReverbConfig.Draft = .init()
    public var pending: ReverbConfig.Draft = .init()

    public var enabled: ToggleFeature.State
    public var locked: ToggleFeature.State
    public var wetDryMix: KnobFeature.State

    public var isDirty: Bool {
      pending.enabled != device.enabled ||
      pending.roomPreset != device.roomPreset ||
      pending.wetDryMix != device.wetDryMix
    }

    public init(parameters: AUParameterTree) {
      @Shared(.reverbLockEnabled) var lockEnabled
      self.locked = .init(isOn: lockEnabled, displayName: "Lock")
      self.enabled = .init(isOn: false, displayName: "On")
      self.wetDryMix = .init(parameter: parameters[.reverbAmount])
    }
  }

  public enum Action {
    case activePresetIdChanged(Preset.ID?)
    case debouncedSave
    case debouncedUpdate
    case enabled(ToggleFeature.Action)
    case locked(ToggleFeature.Action)
    case task
    case roomPresetChanged(AVAudioUnitReverbPreset)
    case wetDryMix(KnobFeature.Action)
  }

  private enum CancelId {
    case debouncedSave
    case debouncedUpdate
    case monitorActivePresetId
  }

  @Dependency(\.mainQueue) var mainQueue
  @Dependency(\.defaultDatabase) private var database
  @Dependency(\.reverbDevice) private var reverbDevice
  @Shared(.activeState) private var activeState

  public var body: some ReducerOf<Self> {

    Scope(state: \.enabled, action: \.enabled) { ToggleFeature() }
    Scope(state: \.locked, action: \.locked) { ToggleFeature() }
    Scope(state: \.wetDryMix, action: \.wetDryMix) { KnobFeature(parameter: parameters[.reverbAmount]) }

    Reduce { state, action in
      switch action {
      case let .activePresetIdChanged(presetId): return activePresetIdChanged(&state, presetId: presetId)
      case .debouncedSave: return save(&state)
      case .debouncedUpdate: return update(&state)
      case .enabled: return updateAndSave(&state, path: \.enabled, value: state.enabled.isOn)
      case .locked: return updateLocked(&state)
      case .task: return monitorActivePresetId()
      case let .roomPresetChanged(value): return roomPresetChanged(&state, room: value)
      case .wetDryMix: return updateAndSave(&state, path: \.wetDryMix, value: state.wetDryMix.value)
      }
    }
  }
}

extension ReverbFeature {

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
        try ReverbConfig.upsert {
          state.pending
        }
        .execute(db)
      }
    }

    let config = ReverbConfig.draft(for: presetId)
    print("loaded \(config)")
    reverbDevice.setConfig(config)
    state.device = config
    state.pending = config

    return .merge(
      reduce(into: &state, action: .enabled(.setValue(state.device.enabled))),
      reduce(into: &state, action: .wetDryMix(.setValue(state.device.wetDryMix))),
    )
  }

  private func updateAndSave<T: BinaryFloatingPoint>(
    _ state: inout State,
    path: WritableKeyPath<ReverbConfig.Draft, T>,
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
    path: WritableKeyPath<ReverbConfig.Draft, T>,
    value: T
  ) -> Effect<Action> {

    state.pending[keyPath: path] = value
    if state.device[keyPath: path] == value {
      return .none
    }

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
      try ReverbConfig.upsert {
        state.device
      }
      .returning(\.self)
      .fetchOneForced(db)
    }

    guard let unwrapped = found else {
      print("skipping unwrapped nil")
      return .none
    }

    let config: ReverbConfig.Draft = .init(unwrapped)
    state.device = config
    state.pending = config

    print("upsert: ", state.device)

    return .none
  }

  private func update(_ state: inout State) -> Effect<Action> {
    state.device = state.pending
    reverbDevice.setConfig(state.device)
    return .none
  }

  private func monitorActivePresetId() -> Effect<Action> {
    .publisher {
      $activeState.activePresetId
        .publisher
        .map { .activePresetIdChanged($0) }
    }.cancellable(id: CancelId.monitorActivePresetId, cancelInFlight: true)
  }

  private func roomPresetChanged(_ state: inout State, room: AVAudioUnitReverbPreset) -> Effect<Action> {
    return updateAndSave(&state, path: \.roomPreset, value: room)
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
    .task { await store.send(.task).finish() }
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

    let parameterTree = ParameterAddress.createParameterTree()
    prepareDependencies {
      // swiftlint:disable:next force_try
      $0.defaultDatabase = try! appDatabase()
      $0.reverbDevice = .init(getConfig: {
        ReverbConfig.Draft()
      }, setConfig: {
        print("ReverbDevice.setConfig:", $0)
      })
    }

    return VStack {
      ScrollView(.horizontal) {
        ReverbView(store: Store(initialState: .init(parameters: parameterTree)) {
          ReverbFeature(parameters: parameterTree)
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
  ReverbView.preview
}
