// Copyright © 2025 Brad Howes. All rights reserved.

import AppRoot
import ComposableArchitecture
import SwiftUI

@main
struct SoundFontsPlusApp: App {

  init() {
    AppRoot.prepareDependencies()
  }

  var body: some Scene {
    WindowGroup {
      if !isTesting {
        ContentView()
      }
    }
  }
}

struct ContentView: View {
  var body: some View {
    ZStack {
      Color.black
        .ignoresSafeArea(edges: .all)
      AppRootView(store: Store(initialState: .init()) { AppRoot() })
        .environment(\.colorScheme, .dark)
#if os(iOS)
      // We don't want to mistake music keyboard activity for iOS app switching or other system gestures
        .defersSystemGestures(on: [.bottom, .leading, .trailing])
#endif
    }
  }
}
