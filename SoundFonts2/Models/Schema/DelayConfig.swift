// Copyright © 2025 Brad Howes. All rights reserved.

import AVFoundation
import SharingGRDB
import Tagged

@Table
public struct DelayConfig: Hashable, Identifiable, Sendable {
  public typealias ID = Tagged<Self, Int64>

  public let id: ID

  public var time: AUValue = 0.25
  public var feedback: AUValue = 0.70
  public var cutoff: AUValue = 2000.0
  public var wetDryMix: AUValue = 0.5
  public var enabled: Bool = false

  public var audioConfigId: AudioConfig.ID?
}

extension DelayConfig.Draft: Equatable, Sendable {}

extension DelayConfig {

  /**
   Create a duplicate of our settings.

   - parameter audioConfigId: the AudioConfig row to associate with
   - returns: cloned instance
   */
  public func clone(audioConfigId: AudioConfig.ID) -> Self? {
    let dupe = Draft(
      time: self.time,
      feedback: self.feedback,
      cutoff: self.cutoff,
      wetDryMix: self.wetDryMix,
      enabled: self.enabled,
      audioConfigId: audioConfigId
    )

    @Dependency(\.defaultDatabase) var database
    return try? database.write {
      try Self.insert(dupe).returning(\.self).fetchOne($0)
    }
  }
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
