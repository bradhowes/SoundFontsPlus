// Copyright © 2025 Brad Howes. All rights reserved.

import AVFoundation
import SharingGRDB
import Tagged

@Table
public struct AudioConfig: Hashable, Identifiable, Sendable {
  public typealias ID = Tagged<Self, Int64>

  public let id: ID
  public var gain: Double = 0.0
  public var pan: Double = 0.0
  public var keyboardLowestNoteEnabled: Bool = true
  public var keyboardLowestNote: Note = .C4
  public var pitchBendRange: Int = 2

  public var customTuningEnabled: Bool = false
  public var customTuning: Double = 440.0

  public var presetId: Preset.ID?
}

extension AudioConfig.Draft: Equatable, Sendable {}

extension AudioConfig {

  /// Obtain the `DelayConfig.Draft` value associated with this config/preset. If one does not exist, then
  /// return one with default values. Goal is to only save an entry when there is a deviation from
  /// the default values.
  public var delayConfig: DelayConfig? {
    @Dependency(\.defaultDatabase) var database
    return (try? database.read { db in
      let query = DelayConfig.all.where { $0.audioConfigId.eq(self.id) }
      return try query.fetchOne(db)
    })
  }

  public var delayConfigDraft: DelayConfig.Draft {
    if let delayConfig = self.delayConfig {
      return .init(delayConfig)
    } else {
      return .init(audioConfigId: self.id)
    }
  }

  /// Obtain the `ReverbConfig.Draft` value associated with this config/preset. If one does not exist, then
  /// return one with default values. Goal is to only save an entry when there is a deviation from
  /// the default values.
  public var reverbConfig: ReverbConfig? {
    @Dependency(\.defaultDatabase) var database
    return (try? database.read { db in
      let query = ReverbConfig.all.where { $0.audioConfigId.eq(self.id) }
      return try query.fetchOne(db)
    })
  }

  public var reverbConfigDraft: ReverbConfig.Draft {
    if let reverbConfig = self.reverbConfig {
      return .init(reverbConfig)
    } else {
      return .init(audioConfigId: self.id)
    }
  }
}

extension AudioConfig {

  static func migrate(_ migrator: inout DatabaseMigrator) {
    migrator.registerMigration(Self.tableName) { db in
      try #sql(
      """
      CREATE TABLE "\(raw: Self.tableName)" (
        "id" INTEGER PRIMARY KEY AUTOINCREMENT,
        "gain" REAL NOT NULL,
        "pan" REAL NOT NULL,
        "keyboardLowestNoteEnabled" INTEGER NOT NULL CHECK ("keyboardLowestNoteEnabled" in (0, 1)),
        "keyboardLowestNote" TEXT NOT NULL,
        "pitchBendRange" INTEGER NOT NULL,
        "customTuningEnabled" INTEGER NOT NULL CHECK ("customTuningEnabled" in (0, 1)),
        "customTuning" REAL NOT NULL,
        "presetId" INTEGER,
      
        FOREIGN KEY("presetId") REFERENCES "presets"("id") ON DELETE CASCADE
      ) STRICT
      """
      )
      .execute(db)
//
//      try #sql(
//      """
//      CREATE UNIQUE INDEX IF NOT EXISTS "audioConfigIndex" ON "\(raw: Self.tableName)" (
//        "favoriteId" INTEGER,
//        "presetId" INTEGER
//      ) STRICT
//      """
//      )
//      .execute(db)
    }
  }
}
