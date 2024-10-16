// Copyright © 2024 Brad Howes. All rights reserved.

import ComposableArchitecture
import SwiftUI
import SwiftData

import Models
import TagsFeature

@main
struct SoundFonts2App: App {
  var body: some Scene {
    WindowGroup {
      let tags = (try? TagModel.tags()) ?? []
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
