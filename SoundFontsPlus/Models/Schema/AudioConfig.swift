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

  public var keyboardLowestNoteEnabled: Bool = false
  public var keyboardLowestNote: Note = .C4
  public var pitchBendRange: Int = 2

  public var customTuningEnabled: Bool = false
  public var customTuning: Double = 440.0

  public var presetId: Preset.ID
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
        "presetId" INTEGER NOT NULL,

        FOREIGN KEY("presetId") REFERENCES "presets"("id") ON DELETE CASCADE
      ) STRICT
      """
      )
      .execute(db)
    }
  }
}

extension AudioConfig.Draft: Equatable, Sendable {}

extension AudioConfig {

  public static func with(key presetId: Preset.ID) -> AudioConfig? {
    @Dependency(\.defaultDatabase) var database
    return try? database.read {
      try Self.all.where { $0.presetId.eq(presetId) }.fetchOne($0)
    }
  }

  /**
   Create a duplicate of the AudioConfig instance, cloning the associated DelayConfig and ReverbConfig rows if they
   exist.

   - parameter presetId: the Preset.ID to associate with
   - returns: cloned instance
   */
  public func clone(presetId: Preset.ID) -> Self? {
    let dupe = Draft(
      gain: self.gain,
      pan: self.pan,
      keyboardLowestNoteEnabled: self.keyboardLowestNoteEnabled,
      keyboardLowestNote: self.keyboardLowestNote,
      pitchBendRange: self.pitchBendRange,
      customTuningEnabled: self.customTuningEnabled,
      customTuning: self.customTuning,
      presetId: presetId
    )

    @Dependency(\.defaultDatabase) var database
    guard let clone = (
      try? database.write {
        try Self.insert {
          dupe
        }.returning(\.self).fetchOne($0)
      }
    ) else {
      return nil
    }

//    if let delayConfig = self.delayConfig {
//      _ = delayConfig.clone(audioConfigId: clone.id)
//    }
//
//    if let reverbConfig = self.reverbConfig {
//      _ = reverbConfig.clone(audioConfigId: clone.id)
//    }
//
    return clone
  }
}
