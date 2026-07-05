// Copyright © 2025 Brad Howes. All rights reserved.

import CoreMIDI
import SQLiteData
import Tagged

/**
 Table that holds customizations associated with a `MIDIUniqueID`. Since this is unique by definition, the table uses
 this value as the primary key and for identity.
 */
@Table
nonisolated public struct MIDIConfig {
  public static var disabledFixedVolume: Int { 128 }

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
      try Self.all
        .find(id)
        .fetchOne(db)
    } ?? nil
  }
}

extension MIDIConfig: Hashable, Identifiable, Sendable {}

extension MIDIConfig.Draft {

  public init(
    uniqueId: MIDIUniqueID,
    autoConnect: Bool,
    fixedVolume: Int
  ) {
    self.uniqueId = uniqueId
    self.autoConnect = autoConnect
    self.fixedVolume = fixedVolume
  }
}
