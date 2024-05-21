// Copyright © 2024 Brad Howes. All rights reserved.

import Foundation
import SwiftData
import SwiftUI

import Models

/**
 Shows a list of SoundFont entities that all have the current active Tag entity
 */
struct TagFilteredSoundFontListView: View {
  @Environment(\.modelContext) var modelContext
  @Query private var soundFonts: [SoundFont]

  @Binding private var activeSoundFont: SoundFont
  @Binding private var selectedSoundFont: SoundFont
  @Binding private var activePreset: Preset

  @State private var pendingDeletion: SoundFont?
  @State private var confirmDeletion: Bool = false

  /**
   Set properties for the view.

   - parameter tag: the tag to filter with
   - parameter activeSoundFont: bindings to the active SoundFont of the parent
   - parameter selectedSoundFont: bindings to the selected SoundFont of the parent
   - parameter activePreset: bindings to the active Preset of the parent
   */
  init(tag: Tag?, activeSoundFont: Binding<SoundFont>, selectedSoundFont: Binding<SoundFont>,
       activePreset: Binding<Preset>) {
    self._activeSoundFont = activeSoundFont
    self._selectedSoundFont = selectedSoundFont
    self._activePreset = activePreset
    _soundFonts = Query(SoundFont.fetchDescriptor(by: tag), animation: .default)
  }

  var body: some View {
    List {
      ForEach(soundFonts) { soundFont in
        SoundFontButtonView(soundFont: soundFont,
                            activeSoundFont: $activeSoundFont,
                            selectedSoundFont: $selectedSoundFont)
        .swipeActions(edge: .trailing, allowsFullSwipe: false) {
          if !soundFont.kind.isBuiltin {
            Button(role: .destructive) {
              pendingDeletion = soundFont
              confirmDeletion = true
            } label: {
              Label("Delete", systemImage: "trash.fill")
            }
          }
          Button(role: .none) {
          } label: {
            Label("Edit", systemImage: "pencil")
          }
        }
      }
    }.alert("Confirm Deletion", isPresented: $confirmDeletion) {
      Button(role: .destructive) {
        delete(soundFont: pendingDeletion!)
        confirmDeletion = false
      } label: {
        Text("Delete")
      }
      Button(role: .cancel) {
        pendingDeletion = nil
        confirmDeletion = false
      } label: {
        Text("Cancel")
      }
    } message: {
      let name = pendingDeletion?.displayName ?? "???"
      Text("Really delete \(name)? This cannot be undone.")
    }
  }

  @MainActor
  private func delete(soundFont: SoundFont) {
    let updateActiveSoundFont = soundFont == activeSoundFont
    let updateSelectedSoundFont = soundFont == selectedSoundFont

    modelContext.delete(soundFont: soundFont)

    try! modelContext.save()

    if updateActiveSoundFont {
      activeSoundFont = modelContext.allSoundFonts()[0]
      activePreset = activeSoundFont.orderedPresets[0]
    }

    if updateSelectedSoundFont {
      selectedSoundFont = activeSoundFont
    }
  }
}
