import SwiftUI
import Models

struct TagButtonView: View {
  @Environment(\.modelContext) var modelContext
  let tag: Tag
  @Binding var activeTag: Tag?
  @Binding var soundFonts: [SoundFont]

  var body: some View {
    Button(action: {
      activeTag = tag
      soundFonts = modelContext.soundFonts(with: tag)
    }, label: {
      Text(tag.name)
        .foregroundStyle(activeTag == tag ? .indigo : .blue)
    }).badge(tag.tagged.count)
  }
}

