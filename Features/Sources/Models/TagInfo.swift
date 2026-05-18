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
    // There are 4 built-in SoundFont.ID values starting at 1. Better would be additional join on SoundFont table to filter
    // on `kind` column.
    let firstFontId = SoundFont.ID(hideBuiltinFonts ? 5 : 0)
    // User tags are always non-negative.
    let firstUserTagId = Tag.ID(0)
    // The minimum font count to hide empty tags if enabled.
    let minFontCountToShow = hideEmptyTags ? 1 : 0
    return tagQueryBase
      .leftJoin(TaggedSoundFont.all) { tag, tagged in
        tag.id.eq(tagged.tagId)
      }
      .having { tag, tagged in
        // Filter to hide empty tags, where empty depends on having no fonts or only having built-in fonts.
        // TODO: remove duplication in `select` expression
        tagged.soundFontId.count(filter: (tagged.soundFontId ?? SoundFont.ID(0)).gte(firstFontId)).gte(minFontCountToShow) ||
        // Always show 'All' tag even if count is zero.
        tag.id.eq(Tag.Ubiquitous.all.id) ||
        // Always show user tags.
        tag.id.gte(firstUserTagId)
      }
      .select { tag, tagged in
        TagInfo.Columns(
          id: tag.id,
          displayName: tag.displayName,
          soundFontsCount: tagged.soundFontId.count(filter: (tagged.soundFontId ?? SoundFont.ID(0)).gte(firstFontId)),
          ordering: tag.ordering
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
