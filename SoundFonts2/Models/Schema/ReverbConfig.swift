// Copyright © 2025 Brad Howes. All rights reserved.

import AVFoundation
import SharingGRDB
import Tagged

@Table
public struct ReverbConfig: Hashable, Identifiable, Sendable {
  public typealias ID = Tagged<Self, Int64>

  public let id: ID

  public var preset: Int = 3
  public var wetDryMix: AUValue = 0.4
  public var enabled: Bool = false

  public var audioConfigId: AudioConfig.ID?
}

extension ReverbConfig.Draft: Equatable, Sendable {}

extension ReverbConfig {

  static func migrate(_ migrator: inout DatabaseMigrator) {
    migrator.registerMigration(Self.tableName) { db in
      try #sql(
      """
      CREATE TABLE "\(raw: Self.tableName)" (
        "id" INTEGER PRIMARY KEY AUTOINCREMENT,

        "preset" INTEGER NOT NULL,
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
