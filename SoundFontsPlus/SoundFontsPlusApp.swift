// Copyright © 2025 Brad Howes. All rights reserved.

import AppRoot
import ComposableArchitecture
import FeatureSupport
import Sharing
import SQLiteData
import SwiftUI

@main
struct SoundFontsPlusApp: App {

  init() {
    if ProcessInfo.processInfo.environment["UI_TESTING"] != nil {
      prepareDependencies {
        $0.defaultAppStorage = .inMemory
        $0.defaultFileStorage = .inMemory
      }
    }
  }

  var body: some Scene {
    WindowGroup {
      if isTesting {
        EmptyView()
      } else {
        let store: StoreOf<AppRoot> = AppRoot.makeWithDependencies()
        @Shared(.colorSchemeBehavior) var colorSchemeBehavior
        ZStack {
          colorSchemeBehavior.rootBackgroundColor
            .ignoresSafeArea()
          ContentView(store: store)
        }
        .tint(.mainAccentColor)
        .environment(\.font, FeatureSupport.Font.body)
        .darkMode()
      }
    }
  }
}

struct ContentView: View {
  private let store: StoreOf<AppRoot>

  init(store: StoreOf<AppRoot>) {
    self.store = store
  }

  var body: some View {
    AppRootView(store: store)
#if os(iOS)
    // We don't want to mistake music keyboard activity for iOS app switching or other system gestures
      .defersSystemGestures(on: [.bottom, .leading, .trailing])
#endif
  }
}
