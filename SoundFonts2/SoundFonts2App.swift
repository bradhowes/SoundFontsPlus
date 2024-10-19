// Copyright © 2024 Brad Howes. All rights reserved.

import ComposableArchitecture
import SwiftUI
import SwiftData

import Models
import SoundFontsFeature
import TagsFeature

@main
struct SoundFonts2App: App {
  var body: some Scene {
    WindowGroup {
      let tags = try! TagModel.tags()
      let soundFonts = try! SoundFontModel.tagged(with: TagModel.Ubiquitous.all.key)
      VStack {
        SoundFontsListView(
          store: Store(
            initialState: .init(
              soundFonts: .init(uniqueElements: soundFonts)
            )) {
              SoundFontsList()
            }
        )
        TagsListView(
          store: Store(
            initialState: .init(
              tags: .init(uniqueElements: tags),
              activeTagKey: TagModel.Ubiquitous.all.key
            )) {
              TagsList()
            }
        )
      }
    }
  }
}
