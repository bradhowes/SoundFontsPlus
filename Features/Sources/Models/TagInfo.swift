// Copyright © 2025 Brad Howes. All rights reserved.

import SQLiteData
import Tagged

/**
 View of the `Tag` table that is used to populate the list of available tags. It holds the `soundFontsCount` of the
 number of SoundFont instances that are members of the tag.
 */
@Selection
public struct TagInfo {
  public let id: FontTag.ID
  public let displayName: String
  public let soundFontsCount: Int
  public let ordering: Int

  public var isUbiquitous: Bool { id.isUbiquitous }
  public var isUserDefined: Bool { id.isUserDefined }
}

extension TagInfo {

  public static var query: Select<TagInfo.Columns.QueryValue, FontTag, TaggedSoundFont?> {
    FontTag
      .group(by: \.id)
      .order(by: \.ordering)
      .leftJoin(TaggedSoundFont.all) {
        $0.id.eq($1.tagId)
      }.select {
        TagInfo.Columns(id: $0.id, displayName: $0.displayName, soundFontsCount: $1.soundFontId.count(), ordering: $0.ordering)
      }
  }
}

extension TagInfo: Equatable, Identifiable, Sendable {}
