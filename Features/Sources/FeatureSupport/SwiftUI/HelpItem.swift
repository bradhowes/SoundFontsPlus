// Copyright © 2025 Brad Howes. All rights reserved.

import Foundation
import SwiftUI
import Sharing

public enum HelpItem: String, CaseIterable {
  case fontsList
  case presetsList
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
    case .presetsList: return "Presets"
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
    case .fontsList: return "The list of available soundfont files. Swipe right or long-press to edit. Swipe left to delete."
    case .presetsList:
      return "The list of presets of the current soundfont. Swipe right to edit or favorite/duplicate. Swipe left to hide/delete."
    case .tagsList: return "The list of tags used to filter visible soundfonts. Swipe right or long-press to edit."
    case .fontsPresetsDivider: return "Drag left/right to adjust spacing between the soundfonts and presets lists."
    case .fontsTagsDivider: return "Drag up/down to adjust spacing between the soundfonts and tags lists."
    case .effectsPanel: return "Controls for the reverb and delay effects."
    case .addButton: return "Add a new soundfont to your library."
    case .tagsButton: return (tagsListVisible ? "Hide" : "Show") + " the tags list."
    case .effectsButton: return (effectsPanelVisible ? "Hide" : "Show") + " the effects panel."
    case .statusWindow: return "Shows the active preset. Double tap to cancel all notes."
    case .shiftDownButton: return "Shifts the keyboard down to play lower notes."
    case .slideToggle:
      return keyboardSlides ?
      "Keyboard will slide with touch movements. Tap to disable." :
      "Played notes change as touch moves. Tap to enable sliding."
    case .shiftUpButton: return "Shifts the keyboard up to play higher notes."
    case .editVisibilityButton: return "Edit the visibility of the presets of the current soundfont."
    case .settingsButton: return "Opens the Settings panel."
    case .moreButton: return "Show additional buttons in the tool bar."
    }
  }
}

extension View {

  @inlinable
  public func helpItemTag(_ id: HelpItem) -> some View {
    helpItemSpotlightSource(id: id)
  }
}
