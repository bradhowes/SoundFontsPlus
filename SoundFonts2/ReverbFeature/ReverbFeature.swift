// Copyright © 2025 Brad Howes. All rights reserved.

import AudioUnit
import AVFoundation
import AUv3Controls
import ComposableArchitecture
import SharingGRDB
import SwiftUI

/**
 Reverb effect controls. A preset can have a reverb configuration. By default all start with none. When enabled, they
 acquire the current settings of the reverb effect, and subsequent changes will update the active preset's configuration.
 There is also a control to "lock" the configuration so that future preset chnages will not affect the delay effect
 value, and changes to the effect controls will affect the preset that was active at the time that the lock was
 enabled.
 */
@Reducer
public struct ReverbFeature {
  let parameters: AUParameterTree

  public init(parameters: AUParameterTree) {
    self.parameters = parameters
  }

  public var state: State { .init(parameters: self.parameters) }

  @ObservableState
  public struct State: Equatable {

    public enum Source: Equatable {
      case none
      case preset(Preset.ID)
    }

    public var source: Source
    public var draft: ReverbConfig.Draft
    public var device: ReverbConfig.Draft

    public var presetHasConfig: Bool
    public var enabled: ToggleFeature.State
    public var locked: ToggleFeature.State
    public var wetDryMix: KnobFeature.State

    public init(parameters: AUParameterTree) {
      @Shared(.reverbLockEnabled) var lockEnabled
      let draft = ReverbConfig.Draft()
      self.source = .none
      self.draft = draft
      self.device = draft
      self.presetHasConfig = false
      self.locked = .init(isOn: lockEnabled, displayName: "Lock")
      self.enabled = .init(isOn: draft.enabled, displayName: "On")
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
    case monitorActivePreset
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
      case .debouncedSave: return debouncedSave(&state)
      case .debouncedUpdate: return debouncedUpdate(&state)
      case .enabled: return applyAndSave(&state, path: \.enabled, value: state.enabled.isOn)
      case .locked: return updateLocked(&state)
      case .task: return monitorActivePreset()
      case let .roomPresetChanged(value): return roomPresetChanged(&state, room: value)
      case .wetDryMix: return applyAndSave(&state, path: \.wetDryMix, value: state.wetDryMix.value)
      }
    }
  }
}

extension ReverbFeature {

  private func activePresetIdChanged(_ state: inout State, presetId: Preset.ID?) -> Effect<Action> {

    print("activePresetIdChanged: \(String(describing: presetId))")

    state.presetHasConfig = false

    // Disregard change if locked
    guard !state.locked.isOn else {
      return .none
    }

    // If no presetId then just take current configuration of delay effect
    guard let presetId else {
      state.draft = reverbDevice.getConfig()
      return .none
    }

    guard state.draft.presetId != presetId else {
      return .none
    }

    state.draft = ReverbConfig.draft(for: presetId)
    state.presetHasConfig = true

    print("ReverbConfig.draft(for: \(presetId)): \(state.draft)")

    return .merge(
      reduce(into: &state, action: .enabled(.setValue(state.draft.enabled))),
      reduce(into: &state, action: .wetDryMix(.setValue(state.draft.wetDryMix))),
    )
  }

  private func applyAndSave<T: Equatable>(
    _ state: inout State,
    path: WritableKeyPath<ReverbConfig.Draft, T>,
    value: T
  ) -> Effect<Action> {

    print("\(path) - \(value)")

    state.draft[keyPath: path] = value

    return .merge(
      .run { send in
        await send(.debouncedUpdate)
      }.debounce(id: CancelId.debouncedUpdate, for: .milliseconds(100), scheduler: mainQueue),
      .run { send in
        await send(.debouncedSave)
      }.debounce(id: CancelId.debouncedSave, for: .milliseconds(1000), scheduler: mainQueue)
    )
  }

  private func debouncedSave(_ state: inout State) -> Effect<Action> {
    print("debouncedSave")

    if state.locked.isOn {
      print("skipping locked")
      return .none
    }

    guard let presetId = activeState.activePresetId else {
      print("skipping nil activePresetId")
      return .none
    }

    state.draft.presetId = presetId

    let found = withErrorReporting {
      try database.write { db in
        try ReverbConfig.upsert {
          state.draft
        }.returning(\.self).fetchOne(db)
      }
    }

    guard let found1 = found, let found2 = found1 else {
      print("skipping nil found")
      return .none
    }

    state.draft = .init(found2)
    print("upsert: ", state.draft)

    return .none
  }

  private func debouncedUpdate(_ state: inout State) -> Effect<Action> {
    reverbDevice.setConfig(state.draft)
    state.device = state.draft
    return .none
  }

  private func monitorActivePreset() -> Effect<Action> {
    return .publisher {
      $activeState.activePresetId.publisher.map {
        return Action.activePresetIdChanged($0) }
    }.cancellable(id: CancelId.monitorActivePreset, cancelInFlight: true)
  }

  private func roomPresetChanged(_ state: inout State, room: AVAudioUnitReverbPreset) -> Effect<Action> {
    guard room != state.draft.roomPreset else {
      return .none
    }

    return applyAndSave(&state, path: \.roomPreset, value: room)
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
        Picker("Room", selection: $store.draft.roomPreset.sending(\.roomPresetChanged)) {
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
    let _ = prepareDependencies {
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
