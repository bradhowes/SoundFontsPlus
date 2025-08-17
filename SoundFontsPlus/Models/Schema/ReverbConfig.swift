// Copyright © 2025 Brad Howes. All rights reserved.

import AVFoundation
import Sharing
import SharingGRDB
import Tagged

@Table
public struct ReverbConfig: Hashable, Identifiable, Sendable {
  public typealias ID = Tagged<Self, Int64>

  public let id: ID
  public var roomPreset: AVAudioUnitReverbPreset = .mediumHall
  public var wetDryMix: Double = 25.0
  public var enabled: Bool = false
  public var presetId: Preset.ID
}

extension ReverbConfig {

  static func migrate(_ migrator: inout DatabaseMigrator) {
    migrator.registerMigration(Self.tableName) { db in
      try #sql(
      """
      CREATE TABLE "\(raw: Self.tableName)" (
        "id" INTEGER PRIMARY KEY AUTOINCREMENT,
        "roomPreset" INTEGER NOT NULL,
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

extension ReverbConfig.Draft {

  public mutating func copy(_ source: Self) {
    self.roomPreset = source.roomPreset
    self.wetDryMix = source.wetDryMix
    self.enabled = source.enabled
  }
}

extension ReverbConfig {

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
          roomPreset: clone.roomPreset,
          wetDryMix: clone.wetDryMix,
          enabled: false,
          presetId: presetId
        )
      }
      return .init(found)
    } ?? .init(
      roomPreset: clone.roomPreset,
      wetDryMix: clone.wetDryMix,
      enabled: false,
      presetId: presetId
    )
  }
}

extension ReverbConfig.Draft: CustomStringConvertible {

  public var description: String {
    "ReverbConfig(\(id ?? -1), roomPreset: \(roomPreset.name), wetDryMix: \(wetDryMix), enabled: \(enabled), presetId: \(presetId))"
  }
}

extension ReverbConfig.Draft: Equatable, Sendable {}
extension AVAudioUnitReverbPreset: @retroactive QueryBindable {}
