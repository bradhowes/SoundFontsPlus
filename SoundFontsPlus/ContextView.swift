// Copyright © 2026 Brad Howes. All rights reserved.

import AppRoot
import ComposableArchitecture
import FeatureSupport
import SwiftUI

struct ContentView: View {
  let store: StoreOf<AppRoot>

  var body: some View {
    AppRootView(store: store)
      .tint(.mainAccentColor)
      .environment(\.font, FeatureSupport.Font.body)
      .useColorScheme()
#if os(iOS)
    // We don't want to mistake music keyboard activity for iOS app switching or other system gestures
      .defersSystemGestures(on: [.bottom, .leading, .trailing])
#endif
  }
}

#Preview {
  let store = prepareDependencies {
    $0.defaultAppStorage = .inMemory
    $0.defaultFileStorage = .inMemory
    installApplicationFont()
    return AppRoot.makeWithDependencies()
  }
  ContentView(store: store)
}
