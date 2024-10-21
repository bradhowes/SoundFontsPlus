// Copyright © 2024 Brad Howes. All rights reserved.

import ComposableArchitecture
import SwiftUI
import SwiftData

import Models
import PresetsFeature
import SoundFontsFeature
import TagsFeature

@main
struct SoundFonts2App: App {

  var body: some Scene {
    WindowGroup {
      VStack {
        SoundFontsListView(store: Store(initialState: .init(soundFonts: soundFonts())) { SoundFontsList() })
        TagsListView(store: Store(initialState: .init(tags: tags())) { TagsList() })
      }
      // PresetsListView(store: Store(initialState: .init(soundFont: soundFonts()[1])) { PresetsList() })
    }
  }

  func tags() -> [TagModel] { try! TagModel.tags() }

  func soundFonts() -> [SoundFontModel] {
    let tags = self.tags()
    var soundFonts = try! SoundFontModel.tagged(with: TagModel.Ubiquitous.all.key)
    if soundFonts.count == 3 {
      let _ = try! Mock.makeSoundFont(name: "Mommy", presetNames: ["One", "Two", "Three", "Four"],
                                      tags: [tags[0], tags[2]])
      let _ = try! Mock.makeSoundFont(name: "Daddy", presetNames: ["One", "Two", "Three", "Four"],
                                      tags: [tags[0], tags[3]])
      soundFonts = try! SoundFontModel.tagged(with: TagModel.Ubiquitous.all.key)
    }
    return soundFonts
  }
}
