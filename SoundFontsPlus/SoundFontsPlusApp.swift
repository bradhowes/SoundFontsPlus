// Copyright © 2025 Brad Howes. All rights reserved.

import AppRoot
import ComposableArchitecture
import FeatureSupport
import Sharing
import SQLiteData
import SwiftUI

/**
 Entry point for the main app.

 Creates the top-level ``AppRoot`` feature up front in order to ensure that all dependencies are properly initialized before being
 used. There are checks to ensure that this is *not* done when testing so that tests will instead use test dependencies.
 */
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
    // NOTE: WindowGroup will be evaluated multiple times when starting up, so it is critical that `store` be initialized once and
    // reused with new `ContentView` instances.
    WindowGroup {
      if isTesting {
        EmptyView()
      } else {
        @Shared(.colorSchemeBehavior) var colorSchemeBehavior
        ZStack {
          colorSchemeBehavior.rootBackgroundColor
            .ignoresSafeArea()
          // swiftlint:disable:next force_unwrapping
          AppRootView(store: SoundFontsPlusApp.store!)
#if os(iOS)
          // We don't want to mistake music keyboard activity for iOS app switching or other system gestures
            .defersSystemGestures(on: [.bottom, .leading, .trailing])
#endif
        }
        .tint(.mainAccentColor)
        .environment(\.font, FeatureSupport.Font.body)
        .useColorScheme()
      }
    }
  }
}
