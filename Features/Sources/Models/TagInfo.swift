// Copyright © 2025 Brad Howes. All rights reserved.

import Sharing
import SQLiteData
import Tagged

/**
 View of the `Tag` table that is used to populate the list of available tags. It holds the `soundFontsCount` of the
 number of SoundFont instances that are members of the tag.
 */
@Selection
public struct TagInfo {
  public let id: Tag.ID
  public let displayName: String
  public let soundFontsCount: Int
  public let ordering: Int

  public var isUbiquitous: Bool { id.isUbiquitous }
  public var isUserDefined: Bool { id.isUserDefined }
}

extension TagInfo {

  public static var queryBase: Select<(), Tag, ()> {
    Tag.all
      .group(by: \.id)
      .order(by: \.ordering)
  }

  public static var filteredQueryBase: Select<(), Tag, ()> {
    @Shared(.hideBuiltinFonts) var hideBuiltinFonts
    if hideBuiltinFonts {
      return queryBase.where { $0.id != Tag.Ubiquitous.builtIn.id }
    }
    return queryBase
  }

  /// - returns: query that returns a ``TagInfo`` for every ``Tag`` that has one or more ``TaggedSoundFont`` associations.
  /// If `hideBuiltinFonts` is `true`, then do not count associations from built-in sound fonts
  public static var queryNonEmpty: Select<TagInfo.Columns.QueryValue, Tag, TaggedSoundFont> {
    @Shared(.hideBuiltinFonts) var hideBuiltinFonts
    return filteredQueryBase
      .join(hideBuiltinFonts ? TaggedSoundFont.all.where { $0.soundFontId > SoundFont.ID(4) } : TaggedSoundFont.all) {
        $0.id.eq($1.tagId)
      }
      .select {
        TagInfo.Columns(id: $0.id, displayName: $0.displayName, soundFontsCount: $1.soundFontId.count(), ordering: $0.ordering)
      }
  }

  /// - returns: query that returns a ``TagInfo`` for every ``Tag`` even if it has no ``TaggedSoundFont`` associations.
  /// If `hideBuiltinFonts` is `true`, then do not count associations from built-in sound fonts
  public static var queryAll: Select<TagInfo.Columns.QueryValue, Tag, TaggedSoundFont?> {
    @Shared(.hideBuiltinFonts) var hideBuiltinFonts
    return filteredQueryBase
      .leftJoin(hideBuiltinFonts ? TaggedSoundFont.all.where { $0.soundFontId > SoundFont.ID(4) } : TaggedSoundFont.all) {
        $0.id.eq($1.tagId)
      }
      .select {
        TagInfo.Columns(id: $0.id, displayName: $0.displayName, soundFontsCount: $1.soundFontId.count(), ordering: $0.ordering)
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
