// Copyright © 2025 Brad Howes. All rights reserved.

import SharingGRDB
import Tagged

@Selection
public struct TagInfo: Equatable, Identifiable, Sendable {
  public let id: Tag.ID
  public let displayName: String
  public let soundFontsCount: Int

  public var isUbiquitous: Bool { id.isUbiquitous }
  public var isUserDefined: Bool { id.isUserDefined }

  public init(id: Tag.ID, displayName: String, soundFontsCount: Int) {
    self.id = id
    self.displayName = displayName
    self.soundFontsCount = soundFontsCount
  }

  public init(tag: Tag) {
    self.init(id: tag.id, displayName: tag.displayName, soundFontsCount: 0)
  }
}
