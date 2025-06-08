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
    public var enabled: ToggleFeature.State
    public var locked: ToggleFeature.State
    public var time: KnobFeature.State
    public var feedback: KnobFeature.State
    public var cutoff: KnobFeature.State
    public var wetDryMix: KnobFeature.State

    public init(parameters: AUParameterTree) {
      self.enabled = .init(isOn: false, displayName: "On")
      self.locked = .init(isOn: false, displayName: "Lock")
      self.time = .init(parameter: parameters[.delayTime])
      self.feedback = .init(parameter: parameters[.delayFeedback])
      self.cutoff = .init(parameter: parameters[.delayCutoff])
      self.wetDryMix = .init(parameter: parameters[.delayWetDryMix])
    }
  }

  public enum Action {
    case enabled(ToggleFeature.Action)
    case locked(ToggleFeature.Action)
    case time(KnobFeature.Action)
    case feedback(KnobFeature.Action)
    case cutoff(KnobFeature.Action)
    case wetDryMix(KnobFeature.Action)
  }

  public var body: some ReducerOf<Self> {

    Scope(state: \.enabled, action: \.enabled) { ToggleFeature() }
    Scope(state: \.locked, action: \.locked) { ToggleFeature() }
    Scope(state: \.time, action: \.time) { KnobFeature(parameter: parameters[.delayTime]) }
    Scope(state: \.feedback, action: \.feedback) { KnobFeature(parameter: parameters[.delayFeedback]) }
    Scope(state: \.cutoff, action: \.cutoff) { KnobFeature(parameter: parameters[.delayCutoff]) }
    Scope(state: \.wetDryMix, action: \.wetDryMix) { KnobFeature(parameter: parameters[.delayWetDryMix]) }

    Reduce { state, action in
      switch action {
      case .enabled: return .none
      case .locked: return .none
      case .time: return .none
      case .feedback: return .none
      case .cutoff: return .none
      case .wetDryMix: return .none
      }
    }
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
