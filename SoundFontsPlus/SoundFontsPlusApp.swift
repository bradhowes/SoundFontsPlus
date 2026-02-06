// Copyright © 2025 Brad Howes. All rights reserved.

import AppRoot
import ComposableArchitecture
import FeatureSupport
import Sharing
import SQLiteData
import SwiftUI

@main
struct SoundFontsPlusApp: App {
  static let store: StoreOf<AppRoot> = AppRoot.makeWithDependencies()

  init() {
    installApplicationFont()
  }

  var body: some Scene {
    WindowGroup {
      if isTesting {
        EmptyView()
      } else {
        @Shared(.colorSchemeBehavior) var colorSchemeBehavior
        ZStack {
          colorSchemeBehavior.rootBackgroundColor
            .ignoresSafeArea()
          ContentView()
        }
        .tint(.mainAccentColor)
        .environment(\.font, FeatureSupport.Font.body)
        .darkMode()
      }
    }
  }
}

struct ContentView: View {
  var body: some View {
    AppRootView(store: SoundFontsPlusApp.store)
#if os(iOS)
    // We don't want to mistake music keyboard activity for iOS app switching or other system gestures
      .defersSystemGestures(on: [.bottom, .leading, .trailing])
#endif
  }
}
