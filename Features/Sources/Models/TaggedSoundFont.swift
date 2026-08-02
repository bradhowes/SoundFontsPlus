// Copyright © 2025 Brad Howes. All rights reserved.

public import SQLiteData
import StructuredQueries
public import Tagged

/**
 The mapping of tags to SoundFont ids. If a SoundFont is a member of a tag, then there will be a `TaggedSoundFont`
 entry for it. As such, this is a many-to-many association.
 */
@Table
nonisolated public struct TaggedSoundFont {
  public let soundFontId: SoundFont.ID
  public let tagId: Tag.ID

  public init(
    soundFontId: SoundFont.ID,
    tagId: Tag.ID
  ) {
    self.soundFontId = soundFontId
    self.tagId = tagId
  }
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
        FOREIGN KEY("soundFontId") REFERENCES "\(raw: SoundFont.tableName)"("id") ON DELETE CASCADE,
        FOREIGN KEY("tagId") REFERENCES "\(raw: Tag.tableName)"("id") ON DELETE CASCADE
      ) STRICT
      """
      )
      .execute(db)
    }
  }
}

extension TaggedSoundFont: Hashable, Sendable {}
