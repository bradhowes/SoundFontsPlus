// Copyright © 2025 Brad Howes. All rights reserved.

import ComposableArchitecture
import HostRoot
import HostSupport
import Sharing
import SwiftUI

@main
struct HostApp: App {

  static let store: StoreOf<HostRoot>? = {
    if ProcessInfo.processInfo.environment["UI_TESTING"] != nil {
      prepareDependencies {
        $0.defaultAppStorage = .inMemory
        $0.defaultFileStorage = .inMemory
      }
      return nil
    } else if isTesting {
      return nil
    } else {
      return HostRoot.makeWithDependencies(subtype: "samp", manufacturer: "appl")
    }
  }()

  init() {}

  var body: some Scene {
    WindowGroup {
      if let store = Self.store {
        ContentView(store: store)
      } else {
        EmptyView()
      }
    }
  }
}
