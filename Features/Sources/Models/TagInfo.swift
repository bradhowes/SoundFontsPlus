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

  private static var tagQueryBase: Select<(), Tag, ()> {
    Tag.queryBase
      .group(by: \.id)
  }

  private static var filteredQueryBase: Select<(), Tag, ()> {
    @Shared(.hideBuiltinFonts) var hideBuiltinFonts
    if hideBuiltinFonts {
      return tagQueryBase.where { $0.id.neq(Tag.Ubiquitous.builtIn.id) }
    }
    return tagQueryBase
  }

  public static var query: Select<TagInfo.Columns.QueryValue, Tag, TaggedSoundFont?> {
    @Shared(.hideBuiltinFonts) var hideBuiltinFonts
    @Shared(.hideEmptyTags) var hideEmptyTags
    // The negative SoundFont.ID values are the built-in sound fonts.
    let firstFontId = SoundFont.ID(hideBuiltinFonts ? 0 : -4)
    // User tags are always non-negative.
    let firstUserTagId = Tag.ID(0)
    // Adjust the minimum font count to hide empty tags if enabled.
    let minFontCountToShow = hideEmptyTags ? 1 : 0
    return filteredQueryBase
      .leftJoin(TaggedSoundFont.all) {
        $0.id.eq($1.tagId)
      }
      .having { tag, taggedSoundFont in
        // Filter to remove built-in sound fonts from counting.
        (taggedSoundFont.soundFontId ?? SoundFont.ID(0)).gte(firstFontId) &&
        (
          // Filter to hide empty tags.
          taggedSoundFont.soundFontId.count().gte(minFontCountToShow) ||
          // Always show 'All' tag even if built-in are not shown and count is zero.
          tag.id.eq(Tag.Ubiquitous.all.id) ||
          // Always show user tags.
          tag.id.gte(firstUserTagId)
        )
      }
      .select {
        TagInfo.Columns(
          id: $0.id,
          displayName: $0.displayName,
          soundFontsCount: $1.soundFontId.count(),
          ordering: $0.ordering
        )
      }
  }
}

extension TagInfo: Equatable, Identifiable, Sendable {}

// Select all:
//
// SELECT "tags"."id" AS "id", "tags"."displayName" AS "displayName", count("taggedSoundFonts"."soundFontId") AS "soundFontsCount", "tags"."ordering" AS "ordering"
// FROM "tags"
// LEFT JOIN "taggedSoundFonts" ON ("tags"."id") = ("taggedSoundFonts"."tagId")
// GROUP BY "tags"."id"
// ORDER BY "tags"."ordering";

// Select all no built-in:
//
// SELECT "tags"."id" AS "id", "tags"."displayName" AS "displayName", count("taggedSoundFonts"."soundFontId") AS "soundFontsCount", "tags"."ordering" AS "ordering"
// FROM "tags"
// LEFT JOIN "taggedSoundFonts" ON ("tags"."id") = ("taggedSoundFonts"."tagId") AND ("taggedSoundFonts"."soundFontId") > 4
// GROUP BY "tags"."id"
// ORDER BY "tags"."ordering";

// Select non-empty
//
// SELECT "tags"."id" AS "id", "tags"."displayName" AS "displayName", count("taggedSoundFonts"."soundFontId") AS "soundFontsCount", "tags"."ordering" AS "ordering"
// FROM "tags"
// JOIN "taggedSoundFonts" ON ("tags"."id") = ("taggedSoundFonts"."tagId")
// GROUP BY "tags"."id"
// ORDER BY "tags"."ordering";

// Select non-empty no built-in
//
// SELECT "tags"."id" AS "id", "tags"."displayName" AS "displayName", count("taggedSoundFonts"."soundFontId") AS "soundFontsCount", "tags"."ordering" AS "ordering"
// FROM "tags"
// JOIN "taggedSoundFonts" ON ("tags"."id") = ("taggedSoundFonts"."tagId") AND ("taggedSoundFonts"."soundFontId") > 4
// GROUP BY "tags"."id"
// ORDER BY "tags"."ordering";
