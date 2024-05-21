// Copyright © 2024 Brad Howes. All rights reserved.

import SwiftData
import SwiftUI

import Models
import SF2Picker

/**
 Collection of SoundFont model buttons. Activating a button will show the presets associated with the SoundFont, but
 will not change the active preset.
 */
struct SoundFontsListView: View {
  @Environment(\.modelContext) var modelContext: ModelContext
  @Query(sort: \Tag.name) private var tags: [Tag]

  @Binding var selectedSoundFont: SoundFont
  @Binding var activeSoundFont: SoundFont
  @Binding var activePreset: Preset

  // @State private var soundFonts: [SoundFont] = []
  @State private var activeTag: Tag?
  @State private var addingSoundFont: Bool = false

  @State private var pickerResults: [URL] = []
  @State private var showingAddedSummary: Bool = false
  @State private var addedSummary: LocalizedStringKey = "" {
    didSet {
      showingAddedSummary = addedSummary != ""
    }
  }

  var body: some View {
    NavigationStack {
      TagFilteredSoundFontListView(tag: activeTag, activeSoundFont: $activeSoundFont, selectedSoundFont: $selectedSoundFont,
                                   activePreset: $activePreset)
      .navigationTitle("Files")
      .toolbar {
        TagPickerView(activeTag: $activeTag)
        Button(LocalizedStringKey("Add"), systemImage: "plus", action: { addingSoundFont = true })
      }
    }.sheet(isPresented: $addingSoundFont) {
      SF2PickerView(pickerResults: $pickerResults)
    }.onChange(of: pickerResults) { _, newValue in
      if !newValue.isEmpty {
        addSoundFonts(urls: newValue)
      }
    }.alert("Add Complete", isPresented: $showingAddedSummary) {
      // add buttons here
    } message: {
      Text(addedSummary)
    }
  }
}

private extension SoundFontsListView {

  @MainActor
  func addSoundFonts(urls: [URL]) {
    let result = modelContext.picked(urls: urls)
    addedSummary = generateResultMessage(result: result)
    pickerResults = []
  }

  @MainActor
  func generateResultMessage(result: ModelContext.PickedStatus) -> LocalizedStringKey {
    if result.bad.isEmpty {
      return "^[Successfuly added \(result.good) file](inflect: true)."
    } else if result.good == 0 {
      return "^[Failed to add \(result.bad.count) file](inflect: true)."
    } else {
      return "^[Successfully added \(result.good) file but, failed to add \(result.bad.count)](inflect: true)."
    }
  }
}

struct SoundFontsListView_Previews: PreviewProvider {
  static let modelContainer = VersionedModelContainer.make(isTemporary: true)
  static var previews: some View {
    let soundFont = modelContainer.mainContext.allSoundFonts()[0]

    @State var selectedSoundFont: SoundFont = soundFont
    @State var activeSoundFont: SoundFont = soundFont
    @State var activePreset: Preset = soundFont.orderedPresets[0]

    SoundFontsListView(selectedSoundFont: $selectedSoundFont,
                       activeSoundFont: $activeSoundFont,
                       activePreset: $activePreset)
      .environment(\.modelContext, modelContainer.mainContext)
  }
}
