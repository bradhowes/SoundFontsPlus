// Copyright © 2024 Brad Howes. All rights reserved.

import Foundation
import SwiftData
import SwiftUI

import Models

struct TagPickerView: View {
  @Environment(\.modelContext) private var modelContext
  @Query(sort: \Tag.name) private var tags: [Tag]

  @Binding private var activeTag: Tag?
  @State private var activeTagName: String

  init(activeTag: Binding<Tag?>) {
    let name = activeTag.wrappedValue?.name ?? Tag.Ubiquitous.all.name
    self._activeTag = activeTag
    self.activeTagName = name
  }

  var body: some View {
    Picker("Tag", selection: $activeTagName) {
      ForEach(tags) { tag in
        Text(tag.name)
          .tag(tag.name)
      }
    }.onChange(of: activeTagName) { oldValue, newValue in
      guard let tag = modelContext.findTag(name: newValue) else {
        fatalError("Unexpected nil value from fiindTag")
      }
      activeTag = tag
    }
  }
}
