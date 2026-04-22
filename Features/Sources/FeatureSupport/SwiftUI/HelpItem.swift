// Copyright © 2025 Brad Howes. All rights reserved.

import Foundation
import SwiftUI
import Sharing

public enum HelpItem: CaseIterable {
  case fontsList
  case fontsListHeader
  case presetsList
  case presetsListHeader
  case presetsListIndex
  case tagsList
  case fontsPresetsDivider
  case fontsTagsDivider
  case effectsPanel
  case addButton
  case tagsButton
  case effectsButton
  case statusWindow
  case shiftDownButton
  case slideToggle
  case shiftUpButton
  case editVisibilityButton
  case settingsButton
  case moreButton

  public var title: Text {
    switch self {
    case .fontsList: return Text("Fonts")
    case .fontsListHeader: return Text("Fonts Header")
    case .presetsList: return Text("Presets")
    case .presetsListHeader: return Text("Presets Header")
    case .presetsListIndex: return Text("Presets Index")
    case .tagsList: return Text("Tags")
    case .fontsPresetsDivider: return Text("Fonts/Presets Divider")
    case .fontsTagsDivider: return Text("Fonts/Tags Divider")
    case .effectsPanel: return Text("Effects")
    case .addButton: return Text("Add")
    case .tagsButton: return Text("Tags")
    case .effectsButton: return Text("Effects")
    case .statusWindow: return Text("Status")
    case .shiftDownButton: return Text("Keyboard Down")
    case .slideToggle: return Text("Keyboard Sliding")
    case .shiftUpButton: return Text("Keyboard Up")
    case .editVisibilityButton: return Text("Preset Visibility")
    case .settingsButton: return Text("Settings")
    case .moreButton: return Text("More Buttons")
    }
  }

  public var message: Text {
    switch self {
    case .fontsList:
      return Text("""
List of available soundfont files.
• Tap to see presets in a soundfont.
• Swipe right or long-press to edit soundfont info.
• Swipe left to delete.
""")
    case .fontsListHeader:
      return Text("""
* Double-tap on header to delete multiple soundfonts.
• Tap on \(Image(systemName: "magnifyingglass")) to search on soundfont names.
""")
    case .presetsList:
      return Text("""
The list of presets and favorites for the selected soundfont.
• Tap to activate.
• Swipe right to edit or make favorite/duplicate.
• Swipe left to hide or delete.
See options in Settings panel to change preset ordering.
""")
    case .presetsListHeader:
      return Text("""
• Tap on section header to show previous section header.
• Double-tap to show first section.
• Tap on \(Image(systemName: "magnifyingglass")) to search preset names.
""")
    case .presetsListIndex:
      return Text("""
Tap to quickly scroll to preset section.
""")
    case .tagsList:
      return Text("""
List of tags to filter visible soundfonts.
• Swipe right or long-press to edit tags.
""")
    case .fontsPresetsDivider:
      return Text("""
Divider between soundfonts and presets lists.
• Drag left/right to adjust spacing given to each.
""")
    case .fontsTagsDivider:
      return Text("""
Divider between soundfonts and tags lists.
• Drag up or down to adjust spacing given to each.
• Double-tap to hide tags list.
""")
    case .effectsPanel:
      return Text("""
Controls for the reverb and delay effects. \
Each preset/favorite can have its own effect settings. \
Use the lock switch to keep same settings across preset changes.
""")
    case .addButton:
      return Text("""
Add soundfont to your library. \
Presents a file browser for selecting one or more files or an entire folder.
""")
    case .tagsButton:
      return Text("Show or hide the tags list.")
    case .effectsButton:
      return Text("Show or hide the effects panel.")
    case .statusWindow:
      return Text("""
Shows the active preset. \
• Tap once to show the active preset.
• Double tap to stop all playing notes, including any from a MIDI controller.
""")
    case .shiftDownButton:
      return Text("""
Shifts the keyboard down to play lower notes.
""")
    case .slideToggle:
      return Text("""
Toggle how Keyboard behaves when touches move. \
• Slide mode will shift the keyboard as the touch moves.
• Fixed mode will change the notes being played when the touches change keys.
""")
    case .shiftUpButton:
      return Text("""
Shifts the keyboard up to play higher notes.
""")
    case .editVisibilityButton:
      return Text("""
Quickly edit the visibility of the presets of the active soundfont via touch actions.
""")
    case .settingsButton:
      return Text("Show the Settings panel.")
    case .moreButton:
      return Text("Show additional buttons in the tool bar.")
    }
  }
}

extension View {

  /**
   Attach a HelpItm value to a view.

   - parameter id: the value to attach
   - returns: modified view
   */
  @inlinable
  public func helpItemTag(_ id: HelpItem) -> some View {
    helpItem(id: id)
  }
}
