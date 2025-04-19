// Copyright © 2025 Brad Howes. All rights reserved.

import AppFeature
import ComposableArchitecture
import GRDB
import Models
import PresetsFeature
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
      tagsSplit: SplitViewReducer.State(orientation: .vertical),
      presetsSplit: SplitViewReducer.State(orientation: .horizontal)
    )) { RootApp() })
  }

  var body: some Scene {
    WindowGroup {
      contentView()
    }
  }
}
