// Copyright © 2025 Brad Howes. All rights reserved.

import AudioUnit.AUParameters
import BRHSplitView
import ComposableArchitecture
import SwiftUI

@main
struct SoundFontsPlusApp: App {
  let parameters: AUParameterTree

  init() {
    self.parameters = prepareDependencies {
      $0.defaultDatabase = try! appDatabase()
      $0.defaultFileStorage = .fileSystem
      $0.delayDevice = .init(
        getConfig: { DelayConfig.Draft() },
        setConfig: { config in print(config) }
      )
      $0.reverbDevice = .init(
        getConfig: { ReverbConfig.Draft() },
        setConfig: { config in print(config) }
      )

      return ParameterAddress.createParameterTree()
    }
  }

  func contentView() -> some View {
    ZStack {
      Color.black
        .ignoresSafeArea(edges: .all)
      RootAppView(store: Store(initialState: .init(parameters: parameters)) { RootApp() })
        .environment(\.colorScheme, .dark)
    }
  }

  var body: some Scene {
    WindowGroup {
      contentView()
    }
  }
}
