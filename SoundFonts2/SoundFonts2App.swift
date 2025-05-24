// Copyright © 2025 Brad Howes. All rights reserved.

import BRHSplitView
import ComposableArchitecture
import SwiftUI

@main
struct SoundFonts2App: App {
  init() {
    prepareDependencies {
      $0.defaultDatabase = try! appDatabase()
      $0.defaultFileStorage = .fileSystem
    }
  }

  func contentView() -> some View {
    RootAppView(store: Store(initialState: .init()) { RootApp() })
  }

  var body: some Scene {
    WindowGroup {
      contentView()
    }
  }
}
