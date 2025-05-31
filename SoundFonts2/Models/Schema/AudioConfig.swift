// Copyright © 2025 Brad Howes. All rights reserved.

import AVFoundation
import SharingGRDB
import Tagged

@Table
public struct AudioConfig: Hashable, Identifiable, Sendable {
  public typealias ID = Tagged<Self, Int64>

  public let id: ID
  public var gain: Double
  public var pan: Double
  public var keyboardLowestNoteEnabled: Bool
  public var keyboardLowestNote: Note
  public var pitchBendRange: Int

  public var customTuningEnabled: Bool
  public var customTuning: Double
  public let favoriteId: Favorite.ID?
  public let presetId: Preset.ID?
}

extension AudioConfig.Draft: Equatable, Sendable {}

extension AudioConfig.Draft {

  init(presetId: Preset.ID) {
    self.init(
      gain: 0.0,
      pan: 0.0,
      keyboardLowestNoteEnabled: true,
      keyboardLowestNote: .C4,
      pitchBendRange: 2,
      customTuningEnabled: false,
      customTuning: 440.0,
      favoriteId: nil,
      presetId: presetId
    )
  }

  init(favoriteId: Favorite.ID) {
    self.init(
      gain: 0.0,
      pan: 0.0,
      keyboardLowestNoteEnabled: true,
      keyboardLowestNote: .C4,
      pitchBendRange: 2,
      customTuningEnabled: false,
      customTuning: 440.0,
      favoriteId: favoriteId,
      presetId: nil
    )
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
        "favoriteId" INTEGER,
        "presetId" INTEGER,
      
        FOREIGN KEY("favoriteId") REFERENCES "favorites"("id") ON DELETE CASCADE,
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
