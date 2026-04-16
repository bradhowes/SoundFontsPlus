// Copyright © 2025 Brad Howes. All rights reserved.

import HostRoot
import HostSupport
import Sharing
import SwiftUI

@main
struct HostApp: App {

  static let root = Root.makeWithDependencies(subtype: "samp", manufacturer: "appl")
  @Shared(.colorSchemeBehavior) var colorSchemeBehavior

  init() {}

  var body: some Scene {
    WindowGroup {
      RootView(store: Self.root)
        .padding()
        .preferredColorScheme(colorSchemeBehavior.preferredColorScheme)
    }
  }
}
