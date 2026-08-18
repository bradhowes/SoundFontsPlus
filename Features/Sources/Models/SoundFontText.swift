// Copyright © 2026 Brad Howes. All rights reserved.

public import SQLiteData

/**
 Table definition to add FTS5 full-text searching to sound font meta data.
 */
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

  static let tokenizer = "trigram"

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
          "tags",
          tokenize = '\(raw: Self.tokenizer)'
        )
        """
      )
      .execute(db)

      try registerSoundFontInsertTrigger(db)
      try registerSoundFontUpdateTrigger(db)
      try registerSoundFontDeleteTrigger(db)
    }
  }
}

extension SoundFontText {

  private static func registerSoundFontInsertTrigger(_ db: Database) throws {
    try SoundFont.createTemporaryTrigger(
      after: .insert { new in
        SoundFontText.insert {
          SoundFontText.Columns(
            soundFontId: new.id,
            displayName: new.displayName,
            originalName: new.originalName,
            embeddedName: new.embeddedName,
            embeddedComment: new.embeddedComment.spacesForNewlines,
            embeddedAuthor: new.embeddedAuthor.spacesForNewlines,
            embeddedCopyright: new.embeddedCopyright.spacesForNewlines,
            notes: new.notes.spacesForNewlines,
            tags: ""
          )
        }
      }
    ).execute(db)
  }

  private static func registerSoundFontUpdateTrigger(_ db: Database) throws {
    try SoundFont.createTemporaryTrigger(
      after: .update {
        ($0.displayName, $0.notes)
      } forEachRow: { _, new in
        SoundFontText
          .where { $0.soundFontId.eq(new.id) }
          .update {
            $0.displayName = new.displayName
            $0.notes = new.notes.spacesForNewlines
          }
      }
    ).execute(db)
  }

  private static func registerSoundFontDeleteTrigger(_ db: Database) throws {
    try SoundFont.createTemporaryTrigger(
      after: .delete { old in
        SoundFontText
          .where { $0.soundFontId.eq(old.id) }
          .delete()
      }
    ).execute(db)
  }
}

extension QueryExpression where QueryValue == String {

  var spacesForNewlines: some QueryExpression<QueryValue> {
    self.replace("\n", " ")
  }
}
