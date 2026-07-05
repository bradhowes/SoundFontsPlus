// Copyright © 2025 Brad Howes. All rights reserved.

import AVFoundation
import BaseSupport
import SQLiteData
import Tagged

@Table
nonisolated public struct AudioConfig {

  public static var minGain: Double { -90.0 }
  public static var defaultGain: Double { 0.0 }
  public static var maxGain: Double { +12.0 }

  public static var minPan: Double { -100.0 }
  public static var defaultPan: Double { 0.0 }
  public static var maxPan: Double { +100.0 }

  public typealias ID = Tagged<Self, Int64>

  public let id: ID
  /// Initial attenuation of audio samples for this preset. [-90.0, +12.0]
  public var gain: Double = 0.0
  /// Initial pan/balance of audio samples for this preset. [-100.0, +100.0]
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

        FOREIGN KEY("presetId") REFERENCES "\(raw: Preset.tableName)"("id") ON DELETE CASCADE
      ) STRICT
      """
      )
      .execute(db)
    }
  }
}

extension AudioConfig {

  /**
   Fetch the row for a given ID.

   - parameter presetId: the preset ID to look for
   - returns: the value found or `nil`.
   */
  public static func with(presetId: Preset.ID?) -> AudioConfig? {
    guard let presetId else { return nil }
    return withDatabaseReader { db in
      try Self.all
        .where {
          $0.presetId.eq(presetId)
        }.fetchOne(db)
    } ?? nil
  }

  /**
   Save the given config.

   - parameter config: the draft to apply
   - returns: the AudioConfig from the database
   */
  @discardableResult
  public static func save(config: Draft) -> Self? {
    withDatabaseWriter { db in
      try Self.upsert {
        config
      }
      .returning(\.self)
      .fetchOne(db)
    } ?? nil
  }

  /**
   Create a duplicate of the AudioConfig instance.

   - parameter presetId: the Preset.ID to associate with
   - returns: cloned instance
   */
  @discardableResult
  public func clone(presetId: Preset.ID) -> Self? {
    withDatabaseWriter { db in
      try Self.insert {
        Draft(
          gain: self.gain,
          pan: self.pan,
          keyboardLowestNoteEnabled: self.keyboardLowestNoteEnabled,
          keyboardLowestNote: self.keyboardLowestNote,
          pitchBendRange: self.pitchBendRange,
          customTuningEnabled: self.customTuningEnabled,
          customTuning: self.customTuning,
          presetId: presetId
        )
      }
      .returning(\.self)
      .fetchOne(db)
    } ?? nil
  }
}

extension AudioConfig: Hashable, Identifiable, Sendable {}

extension AudioConfig.Draft: Equatable, Sendable {

  public init(
    gain: Double = 0.0,
    pan: Double = 0.0,
    keyboardLowestNoteEnabled: Bool = false,
    keyboardLowestNote: Note = .C4,
    pitchBendRange: Int = 2,
    customTuningEnabled: Bool = false,
    customTuning: Double = 440.0,
    presetId: Preset.ID
  ) {
    self.gain = gain
    self.pan = pan
    self.keyboardLowestNoteEnabled = keyboardLowestNoteEnabled
    self.keyboardLowestNote = keyboardLowestNote
    self.pitchBendRange = pitchBendRange
    self.customTuningEnabled = customTuningEnabled
    self.customTuning = customTuning
    self.presetId = presetId
  }
}

extension Double {
  // Map +12...-90 to initialAttenuation generator -120...900
  public var gainGeneratorValue: AUValue { .init(self * -10.0) }
  // Map -100...+100 to pan generator -500...+500
  public var panGeneratorValue: AUValue { .init(self * 5.0) }
}
