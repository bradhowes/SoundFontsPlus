// Copyright © 2025 Brad Howes. All rights reserved.

public import SQLiteData
import StructuredQueries
public import Tagged

/**
 The mapping of tags to Presegt ids. If a Preset is a member of a tag, then there will be a `TaggedPreset`
 entry for it. As such, this is a many-to-many association.
 */
@Table
nonisolated public struct TaggedPreset {
  public let presetId: Preset.ID
  public let tagId: PresetTag.ID

  public init(
    presetId: Preset.ID,
    tagId: PresetTag.ID
  ) {
    self.presetId = presetId
    self.tagId = tagId
  }
}

extension TaggedPreset {

  static func migrate(_ migrator: inout DatabaseMigrator) {
    migrator.registerMigration(Self.tableName) { db in
      try #sql(
      """
      CREATE TABLE "\(raw: Self.tableName)" (
        "presetId" INTEGER NOT NULL,
        "tagId" INTEGER NOT NULL,
        PRIMARY KEY("presetId", "tagId"),
        FOREIGN KEY("presetId") REFERENCES "\(raw: Preset.tableName)"("id") ON DELETE CASCADE,
        FOREIGN KEY("tagId") REFERENCES "\(raw: PresetTag.tableName)"("id") ON DELETE CASCADE
      ) STRICT, WITHOUT ROWID
      """
      )
      .execute(db)
    }
  }
}

extension TaggedPreset {

  public static func link(presetId: Preset.ID, to tagId: PresetTag.ID) {
    withDatabaseWriter { db in
      try TaggedPreset.insert {
        .init(presetId: presetId, tagId: tagId)
      } onConflictDoUpdate: { _ in }
      .execute(db)
    }
  }

  public static func unlink(presetId: Preset.ID, from tagId: PresetTag.ID) {
    withDatabaseWriter { db in
      try TaggedPreset.all
        .delete()
        .where { $0.presetId.eq(presetId) && $0.tagId.eq(tagId) }
        .execute(db)
    }
  }
}

extension TaggedPreset: Hashable, Sendable {}
