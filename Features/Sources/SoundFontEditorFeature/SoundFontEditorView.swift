// Copyright © 2025 Brad Howes. All rights reserved.

import Dependencies
import Foundation
import SwiftData
import SwiftUI
import Models
import SwiftUISupport

/**
 Shows a list of SoundFont entities that all have the current active Tag entity
 */
public struct SoundFontEditorView: View {
  @State private var soundFont: SoundFontModel
  @FocusState private var displayNameFieldIsFocused: Bool
  private let path: String

  public init(soundFont: SoundFontModel) {
    self.soundFont = soundFont
    self.path = (try? soundFont.kind())?.url.absoluteString ?? "N/A"
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
            label: { Text(soundFont.info.originalName) }
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
            label: { Text(soundFont.info.embeddedName) }
          )
        }
        Section(header: Text("Author")) {
          Text(soundFont.info.embeddedAuthor)
        }
        Section(header: Text("Copyright")) {
          Text(soundFont.info.embeddedCopyright)
        }
        Section(header: Text("Comment")) {
          Text(soundFont.info.embeddedComment)
        }
        Section(header: Text("Kind")) {
          Text("file copy")
        }
        Section(header: Text("Path")) {
          Text("\(try! soundFont.kind().url)")
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
  static var previews: some View {
    @Dependency(\.modelContextProvider) var context
    let fonts = try! SoundFontModel.tagged(with: .all)
    SoundFontEditorView(soundFont: fonts[0])
      .modelContext(context)
  }
}
