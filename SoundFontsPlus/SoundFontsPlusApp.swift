// Copyright © 2025 Brad Howes. All rights reserved.

import AppRoot
import ComposableArchitecture
import FeatureSupport
import Sharing
import SQLiteData
import SwiftUI

@main
struct SoundFontsPlusApp: App {

  static let store: StoreOf<AppRoot>? = {
    if ProcessInfo.processInfo.environment["UI_TESTING"] != nil {
      prepareDependencies {
        $0.defaultAppStorage = .inMemory
        $0.defaultFileStorage = .inMemory
      }
      return nil
    } else if isTesting {
      return nil
    } else {
      return AppRoot.makeWithDependencies()
    }
  }()

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
    // swiftlint:disable:next force_unwrapping
    AppRootView(store: SoundFontsPlusApp.store!)
#if os(iOS)
    // We don't want to mistake music keyboard activity for iOS app switching or other system gestures
      .defersSystemGestures(on: [.bottom, .leading, .trailing])
#endif
  }
}
