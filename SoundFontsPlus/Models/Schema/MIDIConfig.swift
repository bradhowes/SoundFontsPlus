// Copyright © 2025 Brad Howes. All rights reserved.

import CoreMIDI
import SharingGRDB
import Tagged

@Table
public struct MIDIConfig: Identifiable, Hashable, Sendable {
  public var id: Int64 { Int64(uniqueId) }
  @Column(primaryKey: true)
  public var uniqueId: MIDIUniqueID
  public var autoConnect: Bool
  public var fixedVolume: Int
}

extension MIDIConfig {

  public static func with(key uniqueId: MIDIUniqueID) -> MIDIConfig? {
    @Dependency(\.defaultDatabase) var database
    return try? database.read {
      try Self.all.where { $0.uniqueId.eq(uniqueId) }.fetchOne($0)
    }
  }
}

extension MIDIConfig {

  static func migrate(_ migrator: inout DatabaseMigrator) {
    migrator.registerMigration(Self.tableName) { db in
      try #sql(
      """
      CREATE TABLE "\(raw: Self.tableName)" (
        "uniqueId" INTEGER PRIMARY KEY,
        "autoConnect" INTEGER NOT NULL CHECK ("autoConnect" in (0, 1)),
        "fixedVolume" INTEGER NOT NULL
      ) STRICT
      """
      )
      .execute(db)
    }
  }
}
