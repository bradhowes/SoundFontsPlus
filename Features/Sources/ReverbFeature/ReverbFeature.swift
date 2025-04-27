import AudioUnit
import AUv3Controls
import ComposableArchitecture
import Models
import Sharing
import SwiftUI

@Reducer
public struct ReverbFeature {

  @ObservableState
  public struct State: Equatable {
    public var enabled: ToggleFeature.State
    public var locked: ToggleFeature.State
    public var wetDryMix: KnobFeature.State
    public var roomIndex: Int

    public init() {
      self.enabled = .init(isOn: false, displayName: "Delay")
      self.locked = .init(isOn: false, displayName: "Locked")
      self.wetDryMix = .init(
        value: 50.0,
        displayName: "Mix",
        minimumValue: 0.0,
        maximumValue: 100.0,
        logarithmic: false
      )
      self.roomIndex = 0
    }
  }

  public enum Action {
    case enabled(ToggleFeature.Action)
    case locked(ToggleFeature.Action)
    case roomIndexPickerSelected(Int)
    case wetDryMix(KnobFeature.Action)
  }

  public var body: some ReducerOf<Self> {

    Scope(state: \.enabled, action: \.enabled) { ToggleFeature() }
    Scope(state: \.locked, action: \.locked) { ToggleFeature() }
    Scope(state: \.wetDryMix, action: \.wetDryMix) { KnobFeature() }

    Reduce { state, action in
      switch action {
      case .enabled: return .none
      case .locked: return .none
      case .roomIndexPickerSelected(let value):
        state.roomIndex = value
        return .none
      case .wetDryMix: return .none
      }
    }
  }
}

public struct ReverbView: View {
  @Bindable private var store: StoreOf<DelayFeature>

  public init(store: StoreOf<DelayFeature>) {
    self.store = store
  }

  public var body: some View {
    HStack {
      VStack {
        ToggleView(store: store.scope(state: \.enabled, action: \.enabled))
        ToggleView(store: store.scope(state: \.locked, action: \.locked))
      }
      KnobView(store: store.scope(state: \.wetDryMix, action: \.wetDryMix))
    }
  }
}


extension ReverbView {
  static var preview: some View {
    let _ = prepareDependencies {
      $0.defaultDatabase = try! .appDatabase()
    }
    return ReverbView(store: Store(initialState: .init()) { ReverbFeature() })
  }
}

#Preview {
  ReverbView.preview
}
