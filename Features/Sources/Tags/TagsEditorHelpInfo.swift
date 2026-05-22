// Copyright © 2026 Brad Howes. All rights reserved.

import HelpInfoSpotlightOverlay
import SwiftUI

/**
 Collection of unique IDs for views that can show help information. Used in tandom with the `HelpInfoSpotlightOverlay` view
 modifier to identify the views that have help information.
 */
public enum TagsEditorHelpInfo: HelpInfoProvider, CaseIterable {
  case cancelButton
  case editButton
  case doneButton
  case addButton
  case saveButton
  case tagsListVisibility
  case tagsListMembership

  public var title: LocalizedStringKey {
    switch self {
    case .cancelButton: return "Cancel & Close"
    case .saveButton: return "Save & Close"
    case .addButton: return "New Tag"
    case .editButton: return "Edit Mode"
    case .doneButton: return "Exit Edit Mode"
    case .tagsListVisibility, .tagsListMembership: return "Tags List"
    }
  }

  public var text: LocalizedStringKey {
    switch self {
    case .cancelButton: return "Dismiss editor wihtout saving any changes."
    case .saveButton: return "Save changes and then dismiss editor."
    case .addButton: return "Tap to create a new tag with a name you can edit."
    case .editButton: return "Tap to enter editing mode that allows you to rearrange and delete tags."
    case .doneButton: return "Tap to end editing mode."
    case .tagsListVisibility: return """
• Rearrange by tapping \(Image(systemName: .editButtonImageName)) and moving \(Image(systemName: .moveButtonImageName)) handles.
• Tap the \(Image(systemName: .circledCheckMarkOnImageName)) button to change a tag's visibility in the tags list.
• Tap the name to edit.
You cannot rename built-in tags, and the "All" tag is always visible.
"""
    case .tagsListMembership: return """
• Tap the \(Image(systemName: .circledCheckMarkOnImageName)) button to change the association with a tag.
• Tap the name to edit.
You cannot change the associations of built-in tags, nor can you rename them.
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
  public func helpInfoViewTag(_ id: TagsEditorHelpInfo) -> some View { helpInfoViewTag(id: id) }
}
