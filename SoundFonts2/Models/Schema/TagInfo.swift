// Copyright © 2025 Brad Howes. All rights reserved.

import SharingGRDB
import Tagged

/**
 View of the `Tag` table that is used to populate the list of available tags. It holds the `soundFontCount` of the
 number of SoundFont instances that are members of the tag.
 */
@Selection
public struct TagInfo: Equatable, Identifiable, Sendable {
  public let id: FontTag.ID
  public let displayName: String
  public let soundFontsCount: Int

  public var isUbiquitous: Bool { id.isUbiquitous }
  public var isUserDefined: Bool { id.isUserDefined }

  public init(id: FontTag.ID, displayName: String, soundFontsCount: Int) {
    self.id = id
    self.displayName = displayName
    self.soundFontsCount = soundFontsCount
  }

  public init(tag: FontTag) {
    self.init(id: tag.id, displayName: tag.displayName, soundFontsCount: 0)
  }
}
