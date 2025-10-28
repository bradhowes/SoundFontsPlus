// Copyright © 2025 Brad Howes. All rights reserved.

import CoreMIDI
import SQLiteData
import Tagged

/**
 Table that holds customizations associated with a `MIDIUniqueID`. Since this is unique by definition, the table uses
 this value as the primary key and for identity.
 */
@Table
public struct MIDIConfig {
  @Column(primaryKey: true)
  public var uniqueId: MIDIUniqueID
  public var id: Int64 { Int64(uniqueId) }
  public var autoConnect: Bool
  public var fixedVolume: Int
}

extension MIDIConfig {

  static func migrate(_ migrator: inout DatabaseMigrator) {
    migrator.registerMigration(Self.tableName) { db in
      try #sql(
      """
      CREATE TABLE "\(raw: Self.tableName)" (
        "uniqueId" INTEGER PRIMARY KEY NOT NULL,
        "autoConnect" INTEGER NOT NULL CHECK ("autoConnect" in (0, 1)),
        "fixedVolume" INTEGER NOT NULL
      ) STRICT
      """
      )
      .execute(db)
    }
  }
}

extension MIDIConfig {

  public static func with(id: MIDIUniqueID) -> MIDIConfig? {
    withDatabaseReader { db in
      try Self.all.find(id).fetchAll(db)
    }?.first
  }
}

extension MIDIConfig: Hashable, Identifiable, Sendable {}
