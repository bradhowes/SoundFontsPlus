// Copyright © 2025 Brad Howes. All rights reserved.

import AppRoot
import ComposableArchitecture
import FeatureSupport
import MorkAndMIDI
import SQLiteData
import SwiftUI

@main
struct SoundFontsPlusApp: App {
  static let store: StoreOf<AppRoot> = AppRoot.makeWithDependencies()

  @Shared(.colorSchemeBehavior) private var colorSchemeBehavior
  @Environment(\.colorScheme) private var colorScheme

  private var darkModeEnabled: Bool { colorSchemeBehavior == .dark || colorScheme == .dark }
  private var rootColor: Color { darkModeEnabled ? .black : .white }

  init() {
    installApplicationFont()
  }

  var body: some Scene {
    WindowGroup {
      if isTesting {
        EmptyView()
      } else {
        ZStack {
          rootColor
            .ignoresSafeArea()
          ContentView()
            .environment(\.colorScheme, darkModeEnabled ? .dark : .light)
            .tint(.mainAccentColor)
            .environment(\.font, FeatureSupport.Font.body)
        }
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
