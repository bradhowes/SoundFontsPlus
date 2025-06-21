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

    public var draft: ReverbConfig.Draft

    public var enabled: ToggleFeature.State
    public var locked: ToggleFeature.State
    public var wetDryMix: KnobFeature.State

    public init(parameters: AUParameterTree) {
      @Shared(.reverbLockEnabled) var lockEnabled

      let draft = ReverbConfig.active
      self.draft = draft

      self.locked = .init(isOn: lockEnabled, displayName: "Lock")
      self.enabled = .init(isOn: draft.enabled, displayName: "On")
      self.wetDryMix = .init(parameter: parameters[.delayWetDryMix])
    }
  }

  public enum Action {
    case activePresetIdChanged(Preset.ID?)
    case debouncedSave(ReverbConfig.Draft)
    case debouncedUpdate(ReverbConfig.Draft)
    case enabled(ToggleFeature.Action)
    case locked(ToggleFeature.Action)
    case onAppear
    case roomPreset(AVAudioUnitReverbPreset)
    case wetDryMix(KnobFeature.Action)
  }

  private enum CancelId {
    case debouncedSave
    case debouncedUpdate
    case monitorActivePreset
  }

  @Dependency(\.defaultDatabase) private var database
  @Dependency(\.reverbDevice) private var reverbDevice
  @Shared(.activeState) private var activeState

  public var body: some ReducerOf<Self> {

    Scope(state: \.enabled, action: \.enabled) { ToggleFeature() }
    Scope(state: \.locked, action: \.locked) { ToggleFeature() }
    Scope(state: \.wetDryMix, action: \.wetDryMix) { KnobFeature(parameter: parameters[.reverbWetDryMix]) }

    Reduce { state, action in
      switch action {
      case let .activePresetIdChanged(presetId): return activePresetIdChanged(&state, presetId: presetId)
      case let .debouncedSave(config):
        reverbDevice.setConfig(config)
        return .none

      case let .debouncedUpdate(config):
        if config.id != nil {
          withErrorReporting {
            try database.write { db in
              try ReverbConfig.upsert{ config }.execute(db)
            }
          }
        }
        return .none

      case .enabled: return updateReverb(&state)
      case .locked:
        @Shared(.reverbLockEnabled) var lockEnabled
        $lockEnabled.withLock { $0.toggle() }
        return .none
      case .onAppear: return monitorActivePreset()
      case let .roomPreset(value): return changeRoomPreset(&state, room: value)
      case .wetDryMix: return updateReverb(&state)
      }
    }
  }
}

extension ReverbFeature {

  private func activePresetIdChanged(_ state: inout State, presetId: Preset.ID?) -> Effect<Action> {

    // Disregard change if locked
    guard !state.locked.isOn else {
      return .none
    }

    // If no presetId then just take current configuration of delay effect
    guard let presetId else {
      state.draft = reverbDevice.getConfig()
      return .none
    }

    state.draft = ReverbConfig.draft(for: presetId)
    state.enabled.isOn = state.draft.id != nil

    return .merge(
      reduce(into: &state, action: .enabled(.setValue(state.draft.enabled))),
      reduce(into: &state, action: .wetDryMix(.setValue(state.draft.wetDryMix))),
    )
  }

  private func changeRoomPreset(_ state: inout State, room: AVAudioUnitReverbPreset) -> Effect<Action> {
    state.draft.roomPreset = room
    return updateReverb(&state)
  }

  private func monitorActivePreset() -> Effect<Action> {
    return .publisher {
      $activeState.activePresetId.publisher.map {
        return Action.activePresetIdChanged($0) }
    }.cancellable(id: CancelId.monitorActivePreset, cancelInFlight: true)
  }

  private func updateReverb(_ state: inout State) -> Effect<Action> {

    let _ = ReverbConfig.Draft(
      id: state.draft.id,
      roomPreset: state.draft.roomPreset,
      wetDryMix: state.wetDryMix.value / 100.0,
      enabled: state.enabled.isOn
    )

    return .none
//    return .merge(
//      .run { send in
//        try await Task.sleep(for: .milliseconds(300))
//        await send(.debouncedUpdate(config))
//      }.cancellable(id: CancelID.debouncedUpdate),
//      .run { send in
//        try await Task.sleep(for: .milliseconds(500))
//        await send(.debouncedSave(config))
//      }.cancellable(id: CancelID.debouncedSave)
//    )
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
        Picker("Room", selection: $store.draft.roomPreset.sending(\.roomPreset)) {
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
  }
}

extension ReverbView {
  static var preview: some View {
    var theme = Theme()
    theme.controlTrackStrokeStyle = StrokeStyle(lineWidth: 5, lineCap: .round)
    theme.controlValueStrokeStyle = StrokeStyle(lineWidth: 3, lineCap: .round)
    theme.toggleOnIndicatorSystemName = "arrowtriangle.down.fill"
    theme.toggleOffIndicatorSystemName = "arrowtriangle.down"

    let parameterTree = ParameterAddress.createParameterTree()
    let _ = prepareDependencies {
      $0.defaultDatabase = try! appDatabase()
    }
    return ScrollView(.horizontal) {
      ReverbView(store: Store(initialState: .init(parameters: parameterTree)) {
        ReverbFeature(parameters: parameterTree)
      })
      .environment(\.auv3ControlsTheme, theme)
    }
    .padding()
    .border(theme.controlBackgroundColor, width: 1)
  }
}

#Preview {
  ReverbView.preview
}
