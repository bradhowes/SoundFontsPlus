// Copyright © 2026 Brad Howes. All rights reserved.
import ComposableArchitecture
import HostRoot
import HostSupport
import SwiftUI

struct ContentView: View {
  let store: StoreOf<HostRoot>
  @Shared(.colorSchemeBehavior) var colorSchemeBehavior

  var body: some View {
    HostRootView(store: store)
      .padding()
      .preferredColorScheme(colorSchemeBehavior.preferredColorScheme)
  }
}

#Preview {
  let store = prepareDependencies {
    $0.defaultAppStorage = .inMemory
    $0.defaultFileStorage = .inMemory
    return HostRoot.makeWithDependencies(subtype: "samp", manufacturer: "appl")
  }
  ContentView(store: store)
}
