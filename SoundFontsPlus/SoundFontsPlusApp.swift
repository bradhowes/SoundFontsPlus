// Copyright © 2025 Brad Howes. All rights reserved.

import AppRoot
import ComposableArchitecture
import FeatureSupport
import MorkAndMIDI
import SQLiteData
import SwiftUI

@main
struct SoundFontsPlusApp: App {

  // Following Point·Free style from https://github.com/pointfreeco/swift-composable-architecture/blob/main/Examples/SyncUps/SyncUps/App.swift
  static let store: StoreOf<AppRoot> = AppRoot.makeWithDependencies()

  var body: some Scene {
    WindowGroup {
      if isTesting {
        EmptyView()
      } else {
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
      AppRootView(store: SoundFontsPlusApp.store)
        .environment(\.colorScheme, .dark)
#if os(iOS)
      // We don't want to mistake music keyboard activity for iOS app switching or other system gestures
        .defersSystemGestures(on: [.bottom, .leading, .trailing])
#endif
    }
  }
}
