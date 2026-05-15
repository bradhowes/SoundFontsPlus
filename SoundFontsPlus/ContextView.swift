// Copyright © 2026 Brad Howes. All rights reserved.

import AppRoot
import ComposableArchitecture
import FeatureSupport
import SwiftUI

struct ContentView: View {
  let store: StoreOf<AppRoot>

  var body: some View {
    AppRootView(store: store)
  }
}

#Preview {
  let store = prepareDependencies {
    $0.defaultAppStorage = .inMemory
    $0.defaultFileStorage = .inMemory
    installApplicationFont()
    return AppRoot.makeWithDependencies()
  }
  ContentView(store: store)
}
