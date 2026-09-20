public import ComposableArchitecture
import FeatureSupport
public import SwiftUI

public struct TutorialView: View {
  @Bindable private var store: StoreOf<Tutorial>
  private let bottomSpacerMinLength: CGFloat = 24.0
  private let sideTapRegionWidth: CGFloat = 24.0

  public init(store: StoreOf<Tutorial>) {
    self.store = store
  }

  public var body: some View {
    ZStack(alignment: .top) {
      TabView(selection: $store.page) {
        ForEach(Tutorial.Page.allCases, id: \.self) { page in
          Tab(value: page) {
            ScrollView {
              switch page {
              case .intro: IntroView()
              case .fonts: FontsView()
              case .presets: PresetsView()
              case .favorites: FavoritesView()
              case .tags: TagsView()
              case .toolbar1: Toolbar1View()
              case .toolbar2: Toolbar2View()
              case .reverb: ReverbView()
              case .delay: DelayView()
              case .settings: SettingsView()
              case .last: LastView(store: store)
              }
            }
          }
        }
      }
      .tabViewStyle(.page)
      .indexViewStyle(.page(backgroundDisplayMode: .always))
      .animation(.easeInOut(duration: 1.0), value: store.page)
      .transition(.slide)
      .padding([.leading, .trailing], 16)
      HStack {
        Rectangle()
          .fill(.clear)
          .frame(width: sideTapRegionWidth)
          .frame(maxHeight: .infinity)
          .contentShape(Rectangle())
          .onTapGesture {
            store.send(.prev)
          }
        Spacer()
        Rectangle()
          .fill(.clear)
          .frame(width: sideTapRegionWidth)
          .frame(maxHeight: .infinity)
          .contentShape(Rectangle())
          .onTapGesture {
            store.send(.next)
          }
      }
    }
    .toolbar {
      ToolbarItem(placement: .automatic) {
        Button {
          store.send(.dismissButtonTapped, animation: .default)
        } label: {
          Image(systemName: .checkmarkImageName)
        }
      }
    }
  }
}

extension View {

  public func tutorialSheet(_ store: Binding<StoreOf<Tutorial>?>) -> some View {
    self
      .sheet(item: store) { child in
        NavigationStack {
          TutorialView(store: child)
        }
      }
  }
}

#if DEBUG

#Preview {
  Preview(page: .intro)
}

#endif // DEBUG
