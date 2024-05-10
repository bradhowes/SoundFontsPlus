import SwiftUI
import Models

/**
 A button view for a tag. Pressing it updates the collection of `SoundFont` models that are shown.
 */
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
        .foregroundStyle(labelColor)
    }).badge(tag.tagged.count)
  }

  var labelColor: Color {
    activeTag == tag ? .indigo : .blue
  }
}
