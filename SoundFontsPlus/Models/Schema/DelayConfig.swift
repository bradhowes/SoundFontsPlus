// Copyright © 2025 Brad Howes. All rights reserved.

import AVFoundation
import Sharing
import SharingGRDB
import Tagged

@Table
public struct DelayConfig: Hashable, Identifiable, Sendable {
  public typealias ID = Tagged<Self, Int64>

  public let id: ID
  public var time: Double = 0.5
  public var feedback: Double = 25.0
  public var cutoff: Double = 12_000.0
  public var wetDryMix: Double = 50.0
  public var enabled: Bool = false
  public var presetId: Preset.ID
}

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
        "presetId" INTEGER NOT NULL,

        FOREIGN KEY("presetId") REFERENCES "presets"("id") ON DELETE CASCADE
      ) STRICT
      """
      )
      .execute(db)
    }
  }
}

extension DelayConfig.Draft {

  public mutating func copy(_ source: Self) {
    self.time = source.time
    self.feedback = source.feedback
    self.cutoff = source.cutoff
    self.wetDryMix = source.wetDryMix
    self.enabled = source.enabled
  }
}

extension DelayConfig {

  public static func draft(for presetId: Preset.ID, cloning: Draft? = nil) -> Draft {
    fetchDraft(
      presetId: presetId,
      clone: cloning ?? Draft(presetId: presetId),
      where: Self.all.where { $0.presetId.eq(presetId) }
    )
  }

  private static func fetchDraft(presetId: Preset.ID, clone: Draft, where: Where<Self>) -> Draft {
    withDatabaseReader { db in
      guard
        let found = try `where`.fetchOne(db)
      else {
        return .init(
          time: clone.time,
          feedback: clone.feedback,
          cutoff: clone.cutoff,
          wetDryMix: clone.wetDryMix,
          enabled: false,
          presetId: presetId
        )
      }
      return .init(found)
    } ?? .init(
      time: clone.time,
      feedback: clone.feedback,
      cutoff: clone.cutoff,
      wetDryMix: clone.wetDryMix,
      enabled: false,
      presetId: presetId
    )
  }
}

extension DelayConfig.Draft: Equatable, Sendable {}
