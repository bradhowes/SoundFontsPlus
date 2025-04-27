// Copyright © 2025 Brad Howes. All rights reserved.

import AppFeature
import BRHSplitView
import ComposableArchitecture
import DelayFeature
import GRDB
import Models
import PresetsFeature
import ReverbFeature
import SoundFontsFeature
import SwiftUI
import TagsFeature
import ToolBarFeature

@main
struct SoundFonts2App: App {
  init() {
    prepareDependencies {
      $0.defaultDatabase = try! .appDatabase()
      $0.defaultFileStorage = .fileSystem
    }
  }

  func contentView() -> some View {
    RootAppView(store: Store(initialState: .init(
      soundFontsList: SoundFontsList.State(),
      presetsList: PresetsList.State(),
      tagsList: TagsList.State(),
      toolBar: ToolBar.State(),
      tagsSplit: SplitViewReducer.State(
        panesVisible: .primary,
        initialPosition: 0.5
      ),
      presetsSplit: SplitViewReducer.State(
        panesVisible: .both,
        initialPosition: 0.5
      ),
      delay: DelayFeature.State(),
      reverb: ReverbFeature.State()
    )) { RootApp() })
  }

  var body: some Scene {
    WindowGroup {
      contentView()
    }
  }
}
