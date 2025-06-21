// Copyright © 2025 Brad Howes. All rights reserved.

import AudioUnit.AUParameters
import BRHSplitView
import ComposableArchitecture
import SwiftUI

@main
struct SoundFonts2App: App {
  let parameters: AUParameterTree

  init() {
    self.parameters = prepareDependencies {
      $0.defaultDatabase = try! appDatabase()
      $0.defaultFileStorage = .fileSystem
      $0.reverbDevice = .init(
        getConfig: { ReverbConfig.Draft() },
        setConfig: { config in print(config) }
      )
      return ParameterAddress.createParameterTree()
    }
  }

  func contentView() -> some View {
    RootAppView(store: Store(initialState: .init(parameters: parameters)) { RootApp() })
  }

  var body: some Scene {
    WindowGroup {
      contentView()
    }
  }
}
