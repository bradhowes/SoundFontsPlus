// Copyright © 2025 Brad Howes. All rights reserved.

import AVFoundation
import SharingGRDB
import Tagged

@Table
public struct ReverbConfig: Hashable, Identifiable, Sendable {
  public typealias ID = Tagged<Self, Int64>
  public static let global = ID(rawValue: 1)

  public let id: ID
  public var roomPreset: AVAudioUnitReverbPreset = .mediumHall
  public var wetDryMix: Double = 0.4
  public var enabled: Bool = false

  public var presetId: Preset.ID?
}

extension ReverbConfig {

  public static var active: Draft {
    @Shared(.activeState) var activeState
    @Shared(.delayLockEnabled) var lockEnabled
    if lockEnabled {
      let configId = activeState.activeReverbConfigId ?? global
      return draft(for: configId)
    } else if let presetId = activeState.activePresetId {
      return draft(for: presetId)
    }
    return draft(for: global)
  }

  public static func draft(for presetId: Preset.ID) -> Draft {
    draft(where: Self.all.where { $0.presetId.eq(presetId) })
  }

  public static func draft(for key: ReverbConfig.ID) -> Draft {
    draft(where: Self.find(key))
  }

  public func clone(presetId: Preset.ID) -> Self? {
    let dupe = Draft(
      roomPreset: self.roomPreset,
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

extension ReverbConfig {

  private static func draft(where: Where<Self>) -> Draft {
    withDatabase { db in
      guard let found = try `where`.fetchOne(db) else { return Draft() }
      return Draft(found)
    } ?? Draft()
  }
}

extension ReverbConfig.Draft: Equatable, Sendable {}

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
        "presetId" INTEGER,

        FOREIGN KEY("presetId") REFERENCES "presets"("id") ON DELETE CASCADE
      ) STRICT
      """
      )
      .execute(db)
    }
  }
}

extension AVAudioUnitReverbPreset: @retroactive QueryBindable {}
