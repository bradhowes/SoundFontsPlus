// Copyright © 2025 Brad Howes. All rights reserved.

import Sharing
import SQLiteData
import Tagged

/**
 View of the `Tag` table that is used to populate the list of available tags. It holds the `soundFontsCount` of the
 number of SoundFont instances that are members of the tag.
 */
@Selection
nonisolated public struct TagInfo {
  public let id: Tag.ID
  public let displayName: String
  public let soundFontsCount: Int
  public let ordering: Int

  public var isUbiquitous: Bool { id.isUbiquitous }
  public var isUserDefined: Bool { id.isUserDefined }
}

extension TagInfo {

  public static var query: Select<TagInfo.Columns.QueryValue, Tag, (TaggedSoundFont?, SoundFont?)> {
    @Shared(.hideBuiltinFonts) var hideBuiltinFonts
    @Shared(.hideEmptyTags) var hideEmptyTags
    // User tags are always non-negative.
    let firstUserTagId = Tag.ID(0)
    // The minimum font count to hide empty tags if enabled.
    let minFontCountToShow = hideEmptyTags ? 1 : 0
    // The minimum 'kind' to show
    let filteredKind: SoundFont.Kind = hideBuiltinFonts ? .installed : .builtin
    return Tag.queryBase
      .where(\.visible)
      .group(by: \.id)
      .leftJoin(TaggedSoundFont.all) { tag, tagged in
        tag.id.eq(tagged.tagId)
      }
      .leftJoin(SoundFont.all) { _, tagged, soundFont in
        tagged.soundFontId.eq(soundFont.id)
      }
      .having { tag, _, soundFont in
        soundFont.id
          .count(filter: (soundFont.kind ?? SoundFont.Kind.installed).gte(filteredKind))
          .gte(minFontCountToShow) ||
        tag.id.eq(Tag.Ubiquitous.all.id) ||
        tag.id.gte(firstUserTagId)
      }
      .select { tag, _, soundFont in
        TagInfo.Columns(
          id: tag.id,
          displayName: tag.displayName,
          soundFontsCount: soundFont.id
            .count(filter: (soundFont.kind ?? SoundFont.Kind.installed).gte(filteredKind)),
          ordering: tag.ordering
        )
      }
  }
}

extension TagInfo: Equatable, Identifiable, Sendable {}
