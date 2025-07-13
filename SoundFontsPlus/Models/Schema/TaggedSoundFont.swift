// Copyright © 2025 Brad Howes. All rights reserved.

import SharingGRDB
import Tagged

/**
 The mapping of tags to SoundFont ids. If a SoundFont is a member of a tag, then there will be a `TaggedSoundFont`
 entry for it.
 */
@Table
public struct TaggedSoundFont: Hashable, Sendable {
  public let soundFontId: SoundFont.ID
  public let tagId: FontTag.ID
}

extension TaggedSoundFont {

  static func migrate(_ migrator: inout DatabaseMigrator) {
    migrator.registerMigration(Self.tableName) { db in
      try #sql(
      """
      CREATE TABLE "\(raw: Self.tableName)" (
        "soundFontId" INTEGER NOT NULL,
        "tagId" INTEGER NOT NULL,

        PRIMARY KEY("soundFontId", "tagId")
        FOREIGN KEY("soundFontId") REFERENCES "soundFonts"("id") ON DELETE CASCADE,
        FOREIGN KEY("tagId") REFERENCES "fontTags"("id") ON DELETE CASCADE
      ) STRICT
      """
      )
      .execute(db)
    }
  }
}
