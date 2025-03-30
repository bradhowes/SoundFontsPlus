// Copyright © 2025 Brad Howes. All rights reserved.

import ComposableArchitecture
import GRDB
import Models
import PresetsFeature
import SoundFontsFeature
import SwiftUI
import TagsFeature

@main
struct SoundFonts2App: App {
  init() {
    prepareDependencies {
      $0.defaultDatabase = try! .appDatabase()
      $0.defaultFileStorage = .fileSystem
    }
  }

  var body: some Scene {
    WindowGroup {
      NavigationSplitView {
        TagsListView(store: Store(initialState: .init(tags: tags())) { TagsList() })
      } content: {
        SoundFontsListView(store: Store(initialState: .init(soundFonts: soundFonts())) { SoundFontsList() })
      } detail: {
        PresetsListView(store: Store(initialState: .init(soundFont: soundFonts()[1])) { PresetsList() })
      }
    }
  }

  func tags() -> IdentifiedArrayOf<Tag> {
    return Tag.ordered
  }

  func soundFonts() -> [SoundFont] {
    @Dependency(\.defaultDatabase) var database
    let tags = Tag.ordered
    let soundFonts = try? database.read { try tags[0].soundFonts.fetchAll($0) }
    return soundFonts ?? []
  }
}
