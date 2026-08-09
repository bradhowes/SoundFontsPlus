// Copyright © 2026 Brad Howes. All rights reserved.

public import SQLiteData

@Table
nonisolated public struct SoundFontText {
  public let soundFontId: SoundFont.ID
  public var displayName: String
  public let originalName: String
  public let embeddedName: String
  public let embeddedComment: String
  public let embeddedAuthor: String
  public let embeddedCopyright: String
  public var notes: String
  public var tags: String
}

extension SoundFontText: FTS5 {

  static func migrate(_ migrator: inout DatabaseMigrator) {
    migrator.registerMigration(Self.tableName) { db in
      try #sql(
        """
        CREATE VIRTUAL TABLE "\(raw: Self.tableName)" USING FTS5 (
          "soundFontId" UNINDEXED,
          "displayName",
          "originalName",
          "embeddedName",
          "embeddedComment",
          "embeddedAuthor",
          "embeddedCopyright",
          "notes",
          tokenize = 'trigram'
        )
        """
      )
      .execute(db)
    }
  }
}

extension SoundFontText {

  static func installTriggers(_ database: any DatabaseWriter) throws {
    try database.write { db in
      try SoundFont.createTemporaryTrigger(after: .insert { new in
        SoundFontText.insert {
          ($0.soundFontId, $0.displayName, $0.originalName, $0.embeddedName, $0.embeddedComment, $0.embeddedAuthor,
           $0.embeddedCopyright, $0.notes)
        } select: {
          SoundFont
            .find(new.id)
            .select {
              ($0.id, $0.displayName, $0.originalName, $0.embeddedName, $0.embeddedComment, $0.embeddedAuthor,
               $0.embeddedCopyright, $0.notes)
            }
        }
      }).execute(db)

      try SoundFont.createTemporaryTrigger(after: .update {
        ($0.displayName, $0.notes)
      } forEachRow: { _, new in
        SoundFontText
          .where { $0.soundFontId.eq(new.id) }
          .update {
            $0.displayName = new.displayName
            $0.notes = new.notes
          }
      }).execute(db)

      try SoundFont.createTemporaryTrigger(after: .delete { old in
        SoundFontText
          .where { $0.soundFontId.eq(old.id) }
          .delete()
      }).execute(db)
    }
  }
}
