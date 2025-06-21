// Copyright © 2025 Brad Howes. All rights reserved.

import AVFoundation
import Sharing
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

  public static var active: Draft {
    @Shared(.activeState) var activeState
    @Shared(.delayLockEnabled) var lockEnabled
    if lockEnabled {
      let configId = activeState.activeDelayConfigId ?? global
      return draft(for: configId)
    } else if let presetId = activeState.activePresetId {
      return draft(for: presetId)
    }
    return draft(for: global)
  }

  public static func draft(for presetId: Preset.ID) -> Draft {
    draft(where: Self.all.where { $0.presetId.eq(presetId) })
  }

  public static func draft(for key: DelayConfig.ID) -> Draft {
    draft(where: Self.find(key))
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

    return withDatabase {
      let query = Self.insert {
        dupe
      }.returning(\.self)
      guard let found = try query.fetchOne($0) else {
        throw DatabaseError(resultCode: .SQLITE_ERROR, message: "unexpectedly failed fetchOne")
      }
      return found
    }
  }
}

extension DelayConfig {

  private static func draft(where: Where<Self>) -> Draft {
    withDatabase { db in
      guard let found = try `where`.fetchOne(db) else { return Draft() }
      return Draft(found)
    } ?? Draft()
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
