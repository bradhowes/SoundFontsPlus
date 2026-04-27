// Copyright © 2026 Brad Howes. All rights reserved.

import HelpInfoSpotlightOverlay
import SwiftUI

/**
 Collection of unique IDs for views that can show help information. Used in tandom with the `HelpInfoSpotlightOverlay` view
 modifier to identify the views that have help information.
 */
public enum RootHelpInfo: HelpInfoProvider, CaseIterable {
  case fontsList
  case presetsList
  case tagsList
  case fontsPresetsDivider
  case fontsTagsDivider
  case effectsPanel
  // Reverb
  case reverbOn
  case reverbLock
  case reverbRoom
  case reverbAmount
  // Delay
  case delayOn
  case delayLock
  case delayTime
  case delayFeedback
  case delayCutoff
  case delayAmount
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

  public var title: LocalizedStringKey {
    switch self {
    case .fontsList: return "Fonts"
    case .presetsList: return "Presets"
    case .tagsList: return "Tags"
    case .fontsPresetsDivider: return "Fonts/Presets Divider"
    case .fontsTagsDivider: return "Fonts/Tags Divider"
    case .effectsPanel: return "Effects"
      // Reverb
    case .reverbOn: return "Reverb On/Off"
    case .reverbLock: return "Reverb Lock"
    case .reverbRoom: return "Reverb Room"
    case .reverbAmount: return "Reverb Amount"
      // Delay
    case .delayOn: return "Delay On/Off"
    case .delayLock: return "Delay Lock"
    case .delayTime: return "Delay Time"
    case .delayFeedback: return "Delay Feedback"
    case .delayCutoff: return "Delay Cutoff"
    case .delayAmount: return "Delay Amount"
      // Toolbar buttons
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

  public var text: LocalizedStringKey {
    switch self {
    case .fontsList:
      return """
List of available soundfont files.
• Tap to see presets in a soundfont.
• Swipe right or long-press to edit soundfont info.
• Swipe left to delete.
* Double-tap on header to delete multiple soundfonts.
• Tap on \(Image(systemName: .searchButtonImageName)) to search on soundfont names.
"""
    case .presetsList:
      return """
The list of presets and favorites for the selected soundfont.
• Tap to activate.
• Swipe right to edit or make favorite/duplicate.
• Swipe left to hide or delete.
• Tap on section header to show previous section header.
• Double-tap to show first section.
• Tap on \(Image(systemName: .searchButtonImageName)) to search preset names.
See options in \(Image(systemName: .settingsButtonImageName)) Settings panel to change preset ordering.
"""
    case .tagsList:
      return """
List of tags to filter visible soundfonts.
• Swipe right or long-press to edit tags.
"""
    case .fontsPresetsDivider:
      return """
Divider between soundfonts and presets lists.
• Drag left/right to adjust spacing given to each.
"""
    case .fontsTagsDivider:
      return """
Divider between soundfonts and tags lists.
• Drag up or down to adjust spacing given to each.
• Double-tap to hide tags list.
"""
    case .effectsPanel:
      return """
Controls for the reverb and delay effects. \
Each preset/favorite can have its own effect settings. \
Use the lock switches to keep the same settings across preset changes.
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
Shows the active preset.
• Tap once to show the active preset.
• Double-tap to stop all notes, including any from a MIDI controller (aka PANIC).
"""
    case .shiftDownButton:
      return """
Shows the name of the first visible key. Tap to shift the keyboard down to show lower notes values.
"""
    case .slideToggle:
      return """
Controls how Keyboard behaves when touches move while a note is playing.
• \(Image(systemName: .fixedKeyboardButtonImageName)) keyboard does not move with touch movements
• \(Image(systemName: .slidingKeyboardButtonImageName)) keyboard moves with touch movements
"""
    case .shiftUpButton:
      return """
Shows the name of the last visible key. Tap to shift the keyboard up to show higher note values.
"""
    case .editVisibilityButton:
      return """
Show the presets of the active soundfont with toggle buttons to change the preset visibility.
"""
    case .settingsButton:
      return "Show the \(Image(systemName: .settingsButtonImageName)) Settings panel."
    case .moreButton:
      return "Show additional buttons in the tool bar."
      // Reverb
    case .reverbOn:
      return """
Toggle to enable/disable reverb effect.
"""
    case .reverbLock:
      return """
Toggle to lock reverb settings to protect from changes when a preset changes.
"""
    case .reverbRoom:
      return """
The reverb room shape that defines the reverberation engine settings.
• Touch-drag up/down to change
"""
    case .reverbAmount:
      return """
The percentage of the audio output made up of the reverb effect.
• 0% - no reverb effect in the mix.
• 50% - orignal audio and reverb output mixed in same amount.
• 100% - only reverb output in mix.
"""
      // Delay
    case .delayOn:
      return """
Toggle to enable/disable delay effect.
"""
    case .delayLock:
      return """
Toggle to lock delay settings to protect from changes when a preset changes.
"""
    case .delayTime:
      return """
The amount of time between repetitions of the audio from the delay buffer.
"""
    case .delayFeedback:
      return """
The amount of the recorded audio that remixed and saved to the delay buffer.
"""
    case .delayCutoff:
      return """
Controls the low-pass filter cutoff frequency (Hz) applied to audio before it is saved to the delay buffer.
"""
    case .delayAmount:
      return """
The percentage of the audio output made up of the delay effect.
• 0% - no delay effect in the mix.
• 50% - orignal audio and delay output mixed in same amount.
• 100% - only delay output in mix.
"""
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
  public func helpInfoViewTag(_ id: RootHelpInfo) -> some View { helpInfoViewTag(id: id) }
}
