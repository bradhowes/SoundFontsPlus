// Copyright © 2026 Brad Howes. All rights reserved.

public import SQLiteData

/**
 Table definition to add FTS5 full-text searching to preset meta data.
 */
@Table
nonisolated public struct PresetText {
  public let presetId: Preset.ID
  public var displayName: String
  public let originalName: String
  public let embeddedName: String
  public var notes: String
}

extension PresetText: FTS5 {

  static let tokenizer = "trigram"

  static func migrate(_ migrator: inout DatabaseMigrator) {
    migrator.registerMigration(Self.tableName) { db in
      try #sql(
        """
        CREATE VIRTUAL TABLE "\(raw: Self.tableName)" USING FTS5 (
          "presetId" UNINDEXED,
          "displayName",
          "originalName",
          "notes",
          tokenize = '\(raw: Self.tokenizer)'
        )
        """
      )
      .execute(db)

      // Add trigger to insert text seach tokens when sound font inserted
      try Preset.createTemporaryTrigger(after: .insert { new in
        PresetText.insert {
          ($0.presetId, $0.displayName, $0.originalName, $0.notes)
        } select: {
          Preset
            .find(new.id)
            .select {
              ($0.id, $0.displayName, $0.originalName, $0.notes)
            }
        }
      }).execute(db)

      // Add trigger to update text seach tokens when sound font meta data changes
      try Preset.createTemporaryTrigger(after: .update {
        ($0.displayName, $0.notes)
      } forEachRow: { _, new in
        PresetText
          .where { $0.presetId.eq(new.id) }
          .update {
            $0.displayName = new.displayName
            $0.notes = new.notes
          }
      }).execute(db)

      // Add trigger to delete text seach tokens when sound font deleted
      try Preset.createTemporaryTrigger(after: .delete { old in
        PresetText
          .where { $0.presetId.eq(old.id) }
          .delete()
      }).execute(db)
    }
  }
}
