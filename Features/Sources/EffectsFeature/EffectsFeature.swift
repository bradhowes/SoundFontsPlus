import AudioUnit
import AUv3Controls
import ComposableArchitecture
import DelayFeature
import Extensions
import Models
import ReverbFeature
import Sharing
import SwiftUI

@Reducer
public struct EffectsFeature {

  @ObservableState
  public struct State: Equatable {
    public var delay: DelayFeature.State
    public var reverb: ReverbFeature.State

    public init() {
      self.delay = .init()
      self.reverb = .init()
    }
  }

  public enum Action {
    case delay(DelayFeature.Action)
    case reverb(ReverbFeature.Action)
  }

  public init() {}

  public var body: some ReducerOf<Self> {

    Scope(state: \.delay, action: \.delay) { DelayFeature() }
    Scope(state: \.reverb, action: \.reverb) { ReverbFeature() }

    Reduce { state, action in
      switch action {
      case .delay: return .none
      case .reverb: return .none
      }
    }
  }
}

public struct EffectsView: View {
  private var store: StoreOf<EffectsFeature>

  public init(store: StoreOf<EffectsFeature>) {
    self.store = store
  }

  public var body: some View {
    ScrollView(.horizontal) {
      ScrollViewReader { proxy in
        HStack {
          DelayView(store: store.scope(state: \.delay, action: \.delay))
          ReverbView(store: store.scope(state: \.reverb, action: \.reverb))
        }
        .scrollViewProxy(proxy)
      }
    }
  }
}

extension EffectsView {
  static var preview: some View {
    let _ = prepareDependencies {
      $0.defaultDatabase = try! .appDatabase()
    }
    var theme = Theme()
    theme.controlTrackStrokeStyle = StrokeStyle(lineWidth: 5, lineCap: .round)
    theme.controlValueStrokeStyle = StrokeStyle(lineWidth: 3, lineCap: .round)
    theme.toggleOnIndicatorSystemName = "arrowtriangle.down.fill"
    theme.toggleOffIndicatorSystemName = "arrowtriangle.down"
    return EffectsView(store: Store(initialState: .init()) { EffectsFeature() })
      .frame(height: 102)
      .frame(maxHeight: 102)
      .padding()
      .border(theme.controlBackgroundColor, width: 1)
  }
}

#Preview {
  EffectsView.preview
}
