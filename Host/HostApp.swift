// Copyright © 2025 Brad Howes. All rights reserved.

import HostRoot
import SwiftUI

@main
struct HostApp: App {

  init() {
    Root.prepareDependencies(subtype: "samp", manufacturer: "appl")
  }

  var body: some Scene {
    WindowGroup {
      ContentView()
    }
  }
}
