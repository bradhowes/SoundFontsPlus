// Copyright © 2025 Brad Howes. All rights reserved.

import AudioUnit
import AUv3Controls
import ComposableArchitecture
import Sharing
import SwiftUI

/**
 Delay effect controls. A preset can have a delay configuration. By default all start with none. When enabled, they
 acquire the current settings of the delay effect, and subsequent changes will update the active preset's configuration.
 There is also a control to "lock" the configuration so that future preset chnages will not affect the delay effect
 value, and changes to the effect controls will affect the preset that was active at the time that the lock was
 enabled.
 */
@Reducer
public struct DelayFeature {
  let parameters: AUParameterTree

  public init(parameters: AUParameterTree) {
    self.parameters = parameters
  }

  public var state: State { .init(parameters: self.parameters) }

  @ObservableState
  public struct State: Equatable {

    public var draft: DelayConfig.Draft

    public var enabled: ToggleFeature.State
    public var locked: ToggleFeature.State
    public var time: KnobFeature.State
    public var feedback: KnobFeature.State
    public var cutoff: KnobFeature.State
    public var wetDryMix: KnobFeature.State

    public init(parameters: AUParameterTree) {
      @Shared(.delayLockEnabled) var lockEnabled

      let draft = DelayConfig.active
      self.draft = draft

      self.locked = .init(isOn: lockEnabled, displayName: "Lock")
      self.enabled = .init(isOn: draft.enabled, displayName: "On")
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
    case onAppear
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
      case .debouncedSave: return debouncedSave(&state)
      case .debouncedUpdate: return debouncedUpdate(&state)
      case .enabled: return applyAndSave(&state)
      case .locked: return updateLocked(&state)
      case .onAppear: return monitorActivePresetId()
      case .time: return applyAndSave(&state)
      case .feedback: return applyAndSave(&state)
      case .cutoff: return applyAndSave(&state)
      case .wetDryMix: return applyAndSave(&state)
      }
    }
  }
}

extension DelayFeature {

  private func activePresetIdChanged(_ state: inout State, presetId: Preset.ID?) -> Effect<Action> {

    // Disregard change if locked
    guard !state.locked.isOn else {
      return .none
    }

    // If no presetId then just take current configuration of delay effect
    guard let presetId else {
      state.draft = delayDevice.getConfig()
      return .none
    }

    state.draft = DelayConfig.draft(for: presetId)
    state.enabled.isOn = state.draft.id != nil

    return .merge(
      reduce(into: &state, action: .enabled(.setValue(state.draft.enabled))),
      reduce(into: &state, action: .time(.setValue(state.draft.time))),
      reduce(into: &state, action: .feedback(.setValue(state.draft.feedback))),
      reduce(into: &state, action: .cutoff(.setValue(state.draft.cutoff))),
      reduce(into: &state, action: .wetDryMix(.setValue(state.draft.wetDryMix))),
    )
  }

  private func applyAndSave(_ state: inout State) -> Effect<Action> {

    let draft = DelayConfig.Draft(
      id: state.draft.id,
      time: state.time.value,
      feedback: state.feedback.value,
      cutoff: state.cutoff.value,
      wetDryMix: state.wetDryMix.value,
      enabled: state.enabled.isOn
    )

    guard state.draft != draft else {
      return .none
    }

    state.draft = draft

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
    if state.draft.id != nil {
      withErrorReporting {
        try database.write { db in
          try DelayConfig.upsert {
            state.draft
          }.execute(db)
        }
      }
    }
    return .none
  }

  private func debouncedUpdate(_ state: inout State) -> Effect<Action> {
    delayDevice.setConfig(state.draft)
    return .none
  }

  private func monitorActivePresetId() -> Effect<Action> {
    return .publisher {
      $activeState.activePresetId.publisher.map {
        return Action.activePresetIdChanged($0) }
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
    }
  }
}

extension DelayView {
  static var preview: some View {
    var theme = Theme()
    theme.controlTrackStrokeStyle = StrokeStyle(lineWidth: 5, lineCap: .round)
    theme.controlValueStrokeStyle = StrokeStyle(lineWidth: 3, lineCap: .round)
    theme.toggleOnIndicatorSystemName = "arrowtriangle.down.fill"
    theme.toggleOffIndicatorSystemName = "arrowtriangle.down"

    let parameterTree = ParameterAddress.createParameterTree()
    let _ = prepareDependencies {
      $0.defaultDatabase = try! appDatabase()
      $0.delayDevice = .init(getConfig: {
        DelayConfig.Draft()
      }, setConfig: {
        print("DelayDevice.setConfig:", $0)
      })
    }

    return ScrollView(.horizontal) {
      DelayView(store: Store(initialState: .init(parameters: parameterTree)) {
        DelayFeature(parameters: parameterTree)
      })
      .environment(\.auv3ControlsTheme, theme)
    }
    .padding()
    .border(theme.controlBackgroundColor, width: 1)
  }
}

#Preview {
  DelayView.preview
}
