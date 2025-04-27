import AudioUnit
import AUv3Controls
import ComposableArchitecture
import Extensions
import Models
import Sharing
import SwiftUI

@Reducer
public struct DelayFeature {

  @ObservableState
  public struct State: Equatable {
    public var enabled: ToggleFeature.State
    public var locked: ToggleFeature.State
    public var time: KnobFeature.State
    public var feedback: KnobFeature.State
    public var cutoff: KnobFeature.State
    public var wetDryMix: KnobFeature.State

    public init() {
      self.enabled = .init(isOn: false, displayName: "On")
      self.locked = .init(isOn: false, displayName: "Lock")
      self.time = .init(
        value: 0.0,
        displayName: "Time",
        minimumValue: 0.0,
        maximumValue: 2.0,
        logarithmic: false
      )
      self.feedback = .init(
        value: -0.0,
        displayName: "Feedback",
        minimumValue: -100.0,
        maximumValue: 100.0,
        logarithmic: false
      )
      self.cutoff = .init(
        value: 10.0,
        displayName: "Cutoff",
        minimumValue: 10.0,
        maximumValue: 20_000,
        logarithmic: true
      )
      self.wetDryMix = .init(
        value: 50.0,
        displayName: "Mix",
        minimumValue: 0.0,
        maximumValue: 100.0,
        logarithmic: false
      )
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

  public init() {}

  public var body: some ReducerOf<Self> {

    Scope(state: \.enabled, action: \.enabled) { ToggleFeature() }
    Scope(state: \.locked, action: \.locked) { ToggleFeature() }
    Scope(state: \.time, action: \.time) { KnobFeature() }
    Scope(state: \.feedback, action: \.feedback) { KnobFeature() }
    Scope(state: \.cutoff, action: \.cutoff) { KnobFeature() }
    Scope(state: \.wetDryMix, action: \.wetDryMix) { KnobFeature() }

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
  @Environment(\.appPanelBackground) private var appPanelBackground
  private let main: Theme
  private let alt: Theme

  public init(store: StoreOf<DelayFeature>) {
    self.store = store

    self.alt = .init()
    self.alt.toggleOffIndicatorSystemName = "arrowtriangle.down"
    self.alt.toggleOnIndicatorSystemName = "arrowtriangle.down.fill"

    self.main = .init(editorStyle: .grouped)
    self.main.controlTrackStrokeStyle = .init(lineWidth: 6, lineCap: .round)
    self.main.controlValueStrokeStyle = .init(lineWidth: 4, lineCap: .round)
    self.main.controlIndicatorLength = 8
    self.main.controlForegroundColor = Color.teal
    self.main.controlBackgroundColor = Color.gray.opacity(0.3)
    self.main.toggleOffIndicatorSystemName = "arrowtriangle.down"
    self.main.toggleOnIndicatorSystemName = "arrowtriangle.down.fill"
    self.main.textColor = Color.teal
  }

  public var body: some View {
    GroupBox(label: title) {
      HStack(spacing: 16) {
        VStack(alignment: .leading, spacing: 24) {
          ToggleView(store: store.scope(state: \.enabled, action: \.enabled))
          ToggleView(store: store.scope(state: \.locked, action: \.locked))
            .auv3ControlsTheme(alt)
        }
        KnobView(store: store.scope(state: \.time, action: \.time))
        KnobView(store: store.scope(state: \.feedback, action: \.feedback))
        KnobView(store: store.scope(state: \.cutoff, action: \.cutoff))
        KnobView(store: store.scope(state: \.wetDryMix, action: \.wetDryMix))
      }
      .auv3ControlsTheme(main)
    }
    .padding(-6)
  }

  private var title: some View {
    Text("Delay")
      .foregroundStyle(main.controlForegroundColor)
      .font(.title3.smallCaps())
  }
}


extension DelayView {
  static var preview: some View {
    let _ = prepareDependencies {
      $0.defaultDatabase = try! .appDatabase()
    }
    return DelayView(store: Store(initialState: .init()) { DelayFeature() })
  }
}

#Preview {
  DelayView.preview
}
