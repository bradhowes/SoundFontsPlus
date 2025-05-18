// Copyright © 2025 Brad Howes. All rights reserved.

import SharingGRDB
import Tagged

@Table
public struct TaggedSoundFont: Hashable, Sendable {
  public let soundFontId: SoundFont.ID
  public let tagId: Tag.ID
}

extension TaggedSoundFont {

  static func migrate(_ migrator: inout DatabaseMigrator) {
    migrator.registerMigration(Self.tableName) { db in
      try #sql(
      """
      CREATE TABLE "\(raw: Self.tableName)" (
        "id" INTEGER PRIMARY KEY AUTOINCREMENT,
        "soundFontId" INTEGER NOT NULL,
        "tagId" INTEGER NOT NULL,
      
        FOREIGN KEY("soundFontId") REFERENCES "soundFonts"("id") ON DELETE CASCADE,
        FOREIGN KEY("tagId") REFERENCES "tags"("id") ON DELETE CASCADE
      ) STRICT
      """
      )
      .execute(db)
    }
  }
}
