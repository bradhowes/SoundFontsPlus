// Copyright © 2025 Brad Howes. All rights reserved.

import Foundation
import SwiftUI
import Sharing

public enum HelpItem: String, CaseIterable {
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

  public var title: String {
    switch self {
    case .fontsList: return "Fonts"
    case .fontsListHeader: return "Fonts Header"
    case .presetsList: return "Presets"
    case .presetsListHeader: return "Presets Header"
    case .presetsListIndex: return "Presets Index"
    case .tagsList: return "Tags"
    case .fontsPresetsDivider: return "Fonts/Presets Divider"
    case .fontsTagsDivider: return "Fonts/Tags Divider"
    case .effectsPanel: return "Effects"
    case .addButton: return "Add"
    case .tagsButton: return "Tags"
    case .effectsButton: return "Effects"
    case .statusWindow: return "Status"
    case .shiftDownButton: return "Keyboard Down"
    case .slideToggle: return "Keyboard Sliding"
    case .shiftUpButton: return "Keyboard Up"
    case .editVisibilityButton: return "Preset Visibility"
    case .settingsButton: return "Settings"
    case .moreButton: return "More Buttons"
    }
  }

  public var message: String {
    @Shared(.tagsListVisible) var tagsListVisible
    @Shared(.effectsPanelVisible) var effectsPanelVisible
    @Shared(.keyboardSlides) var keyboardSlides

    switch self {
    case .fontsList:
      return """
List of available soundfont files. \
Tap to see presets in a soundfont. \
Swipe right or long-press to edit soundfont info. \
Swipe left to delete.
"""
    case .fontsListHeader:
      return """
Double-tap on header to delete multiple soundfonts. \
Tap on magnifier to search on soundfont names.
"""
    case .presetsList:
      return """
The list of presets and favorites for the selected soundfont. \
Tap to activate. \
Swipe right to edit or make favorite/duplicate. Swipe left to hide or delete. \
See options in Settings panel to change preset ordering.
"""
    case .presetsListHeader:
      return """
Tap on section header to show previous section header. \
Double-tap to show first section. \
Tap on magnifier to search on preset names.
"""
    case .presetsListIndex:
      return """
Tap to quickly scroll to preset section.
"""
    case .tagsList:
      return """
List of tags to filter visible soundfonts. \
Swipe right or long-press to edit tags.
"""
    case .fontsPresetsDivider:
      return """
Divider between soundfonts and presets lists. \
Drag left/right to adjust spacing given to each.
"""
    case .fontsTagsDivider:
      return """
Divider between soundfonts and tags lists. \
Drag up or down to adjust spacing given to each. \
Double-tap to hide tags list.
"""
    case .effectsPanel:
      return """
Controls for the reverb and delay effects. \
Each preset/favorite can have its own effect settings. \
Use the lock switch to keep same settings across preset changes.
"""
    case .addButton:
      return """
Add soundfont to your library. \
Presents a file browser for selecting one or more files or an entire folder.
"""
    case .tagsButton:
      return "Show or hide the tags list."
    case .effectsButton:
      return "Show or hide the effects panel."
    case .statusWindow:
      return """
Shows the active preset. \
Tap once to show the active preset. \
Double tap to stop all playing notes, including any from a MIDI controller.
"""
    case .shiftDownButton:
      return """
Shifts the keyboard down to play lower notes.
"""
    case .slideToggle:
      return """
Toggle how Keyboard behaves when touches move. \
Slide mode will shift the keyboard as the touch moves. \
Fixed mode will change the notes being played when the touches change keys.
"""
    case .shiftUpButton:
      return """
Shifts the keyboard up to play higher notes.
"""
    case .editVisibilityButton:
      return """
Quickly edit the visibility of the presets of the active soundfont via touch actions.
"""
    case .settingsButton:
      return "Show the Settings panel."
    case .moreButton:
      return "Show additional buttons in the tool bar."
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
