// Copyright © 2025 Brad Howes. All rights reserved.

import AVFoundation
import SharingGRDB
import Tagged

@Table
public struct DelayConfig: Hashable, Identifiable {
  public typealias ID = Tagged<Self, Int64>

  public let id: ID
  public var time: AUValue
  public var feedback: AUValue
  public var cutoff: AUValue
  public var wetDryMix: AUValue
  public var enabled: Bool
  public let audioConfigId: AudioConfig.ID
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
        "audioConfigId" INTEGER NOT NULL,

        FOREIGN KEY("audioConfigId") REFERENCES "audioConfigs"("id") ON DELETE CASCADE
      ) STRICT
      """
      )
      .execute(db)
    }
  }
}
