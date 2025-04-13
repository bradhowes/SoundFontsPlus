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
    @Dependency(\.defaultDatabase) var database
    let tags = Tag.ordered
    guard let soundFonts = (try? database.read {
      guard let tag = try Tag.fetchOne($0, id: Tag.Ubiquitous.all.id) else { return Optional<[SoundFont]>.none }
      return try tag.soundFonts.fetchAll($0)
    }) else { fatalError() }

    return RootAppView(store: Store(initialState: .init(
      soundFontsList: SoundFontsList.State(soundFonts: soundFonts),
      presetsList: PresetsList.State(soundFont: soundFonts[0]),
      tagsList: TagsList.State(tags: tags),
      toolBar: ToolBar.State()
    )) { RootApp() })
  }

  var body: some Scene {
    WindowGroup {
      contentView()
    }
  }
}
