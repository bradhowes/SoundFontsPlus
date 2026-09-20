import FeatureSupport
import SwiftUI

struct LastView: View {
  @Bindable private var store: StoreOf<Tutorial>

  init(store: StoreOf<Tutorial>) {
    self.store = store
  }

  var body: some View {
    VStack(spacing: 18) {
      Text("Enjoy!")
        .font(.largeTitle)
        .foregroundStyle(Color.alternateAccentColor)
      Button {
        store.send(.dismissButtonTapped)
      } label: {
        Text("Begin making music")
          .foregroundStyle(.teal)
      }
    }
  }
}
