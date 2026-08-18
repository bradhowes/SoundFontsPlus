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
        PRIMARY KEY("soundFontId", "tagId"),
        FOREIGN KEY("soundFontId") REFERENCES "\(raw: SoundFont.tableName)"("id") ON DELETE CASCADE,
        FOREIGN KEY("tagId") REFERENCES "\(raw: Tag.tableName)"("id") ON DELETE CASCADE
      ) STRICT, WITHOUT ROWID
      """
      )
      .execute(db)

      try registerTaggedSoundFontInsertTrigger(db)
      try registerTaggedSoundFontDeleteTrigger(db)
    }
  }

  private static func registerTaggedSoundFontInsertTrigger(_ db: Database) throws {
    try TaggedSoundFont.createTemporaryTrigger(
      after: .insert { new in
        updateTagsText(for: new.soundFontId)
      }
    ).execute(db)
  }

  private static func registerTaggedSoundFontDeleteTrigger(_ db: Database) throws {
    try TaggedSoundFont.createTemporaryTrigger(
      after: .delete { old in
        updateTagsText(for: old.soundFontId)
      }
    ).execute(db)
  }

  static func getTagsText(for soundFontId: some QueryExpression<SoundFont.ID>) -> Select<String, TaggedSoundFont, Tag> {
    TaggedSoundFont.all
      .where { $0.soundFontId.eq(soundFontId) }
      .join(Tag.all) { $0.tagId.eq($1.id) }
      .select { ("#" + $1.displayName).groupConcat(" ") ?? "" }
  }

  static func updateTagsText(for soundFontId: some QueryExpression<SoundFont.ID>) -> UpdateOf<SoundFontText> {
    SoundFontText
      .where { $0.rowid.eq(SoundFont.find(soundFontId).select(\.rowid)) }
      .update { $0.tags = getTagsText(for: soundFontId) }
  }}

extension TaggedSoundFont: Hashable, Sendable {}
