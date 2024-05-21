// Copyright © 2024 Brad Howes. All rights reserved.

import Foundation
import SwiftData
import SwiftUI
import Models
import SwiftUISupport

/**
 Shows a list of SoundFont entities that all have the current active Tag entity
 */
public struct SoundFontEditorView: View {
  @Environment(\.modelContext) var modelContext

  @State private var soundFont: SoundFont
  @FocusState private var displayNameFieldIsFocused: Bool

  public init(soundFont: SoundFont) {
    self.soundFont = soundFont
    self.displayNameFieldIsFocused = true
  }

  public var body: some View {

    NavigationStack {
      Form {
        Section(header: Text("Name")) {
          TextField("Display Name", 
                    text: $soundFont.displayName
          )
          .clearButton(text: $soundFont.displayName, hasFocus: $displayNameFieldIsFocused)
          .textFieldStyle(.roundedBorder)
          .focused($displayNameFieldIsFocused)
          .textInputAutocapitalization(.never)
          .disableAutocorrection(true)
        }
        Section(header: Text("Tags")) {
          LabeledContent(
            content: {
              Button(
                action: {},
                label: { 
                  Text("Edit Tags")
                }
              )
            },
            label: { Text(tagList) }
          )
        }
        Section(header: Text("Contents")) {
          VStack {
            Text("^[\(soundFont.presets.count) preset](inflect: true)")
            Text("No favorites")
          }
        }
        Section(header: Text("Original Name")) {
          LabeledContent(
            content: {
              Button(
                action: {},
                label: {
                  Text("Use")
                }
              )
            },
            label: { Text(soundFont.originalName) }
          )
        }
        Section(header: Text("Embedded Name")) {
          LabeledContent(
            content: {
              Button(
                action: {},
                label: {
                  Text("Use")
                }
              )
            },
            label: { Text(soundFont.embeddedName) }
          )
        }
        Section(header: Text("Author")) {
          Text(soundFont.embeddedAuthor)
        }
        Section(header: Text("Copyright")) {
          Text(soundFont.embeddedCopyright)
        }
        Section(header: Text("Comment")) {
          Text(soundFont.embeddedComment)
        }
        Section(header: Text("Kind")) {
          Text("file copy")
        }
        Section(header: Text("Path")) {
          Text("\(soundFont.kind.url)")
        }
      }
    }
  }
}

extension SoundFontEditorView {

  var tagList: String {
    soundFont.tags
      .map { $0.name }
      .joined(separator: ", ")
  }
}

struct SoundFontEditorView_Previews: PreviewProvider {
  static let modelContainer = VersionedModelContainer.make(isTemporary: true)
  static var previews: some View {
    let soundFont = modelContainer.mainContext.allSoundFonts()[0]
    SoundFontEditorView(soundFont: soundFont)
      .environment(\.modelContext, modelContainer.mainContext)
  }
}
