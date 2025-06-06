// Copyright © 2025 Brad Howes. All rights reserved.

import AVFoundation
import SharingGRDB
import Tagged

@Table
public struct DelayConfig: Hashable, Identifiable, Sendable {
  public typealias ID = Tagged<Self, Int64>

  public static let global = ID(rawValue: 1)

  public let id: ID
  public var time: Double = 0.25
  public var feedback: Double = 0.70
  public var cutoff: Double = 2000.0
  public var wetDryMix: Double = 0.5
  public var enabled: Bool = false

  public var presetId: Preset.ID?
}

extension DelayConfig {

  public static func with(key presetId: Preset.ID) -> Self? {
    @Dependency(\.defaultDatabase) var database
    return try? database.read { try Self.all.where { $0.presetId.eq(presetId) }.fetchOne($0) }
  }

  public func clone(audioConfigId: AudioConfig.ID) -> Self? {
    let dupe = Draft(
      time: self.time,
      feedback: self.feedback,
      cutoff: self.cutoff,
      wetDryMix: self.wetDryMix,
      enabled: self.enabled,
      presetId: presetId
    )

    @Dependency(\.defaultDatabase) var database
    return try? database.write { try Self.insert(dupe).returning(\.self).fetchOne($0) }
  }
}

extension DelayConfig.Draft: Equatable, Sendable {}

extension DelayConfig {

  static func migrate(_ migrator: inout DatabaseMigrator) {
    migrator.registerMigration(Self.tableName) { db in
      try #sql(
      """
      CREATE TABLE "\(raw: Self.tableName)" (
        "id" INTEGER PRIMARY KEY AUTOINCREMENT,
        "time" REAL NOT NULL,
        "feedback" REAL NOT NULL,
        "cutoff" REAL NOT NULL,
        "wetDryMix" REAL NOT NULL,
        "enabled" INTEGER NOT NULL CHECK ("enabled" in (0, 1)),
        "presetId" INTEGER,

        FOREIGN KEY("presetId") REFERENCES "presets"("id") ON DELETE CASCADE
      ) STRICT
      """
      )
      .execute(db)
    }
  }
}
