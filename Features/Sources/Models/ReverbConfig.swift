// Copyright © 2025 Brad Howes. All rights reserved.

import AVFoundation
import BaseSupport
import Sharing
import SQLiteData
import Tagged

/**
 Configurations for the reverb effect. A ``Preset`` may have one associated with it such that when the preset is active, the
 reverb device receives the associated reverb config settings.
 */
@Table
public struct ReverbConfig {
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

extension ReverbConfig {

  /**
   Fetch the configuration for the given preset ID.

   - parameter presetId: the preset ID to look for
   - returns: the value found or `nil`.
   */
  public static func with(presetId: Preset.ID?) -> Self? {
    guard let presetId else { return nil }
    return withDatabaseReader { db in
      try Self.all
        .where {
          $0.presetId.eq(presetId)
        }.fetchOne(db)
    } ?? nil
  }

  /**
   Create or update delay configuration for a preset.

   - parameter config: the draft to apply
   - returns: the ReverbConfig from the database
   */
  @discardableResult
  public static func save(config: Draft) -> Self? {
    log.info("saving \(config)")
    return withDatabaseWriter { db in
      precondition(config.presetId != -1)
      return try Self.upsert {
        config
      }
      .returning(\.self)
      .fetchOne(db)
    } ?? nil
  }

  /**
   Create a clone of our settings for a new preset/favorite.

   - parameter presetId: the ID of the favorite to assign to the clone
   - returns: cloned config or nil if unable to clone
   */
  public func clone(presetId: Preset.ID) -> Self? {
    var draft = Self.draft(for: presetId, cloning: .init(self))
    draft.enabled = self.enabled
    return Self.save(config: draft)
  }

  /**
   Create new or locate existing Draft for a given preset.

   - parameter presetId: the Preset that owns the reverb config
   - parameter cloning: an existing draft to clone for values
   - returns: new Draft instance
   */
  public static func draft(for presetId: Preset.ID, cloning: Draft? = nil) -> Draft {
    fetchDraft(
      presetId: presetId,
      clone: cloning ?? Draft(presetId: presetId),
      where: Self.all.where { $0.presetId.eq(presetId) }
    )
  }

  private static func cloneDisabledDraft(_ clone: Draft, presetId: Preset.ID) -> Draft {
    .init(
      roomPreset: clone.roomPreset,
      wetDryMix: clone.wetDryMix,
      enabled: false,
      presetId: presetId
    )
  }

  private static func fetchDraft(presetId: Preset.ID, clone: Draft, where: Where<Self>) -> Draft {
    withDatabaseReader { db in
      guard
        let found = try `where`.fetchOne(db)
      else {
        return cloneDisabledDraft(clone, presetId: presetId)
      }
      return .init(found)
    } ?? cloneDisabledDraft(clone, presetId: presetId)
  }
}

extension ReverbConfig: Hashable, Identifiable, Sendable {}

extension ReverbConfig.Draft: Equatable, Sendable {}

extension AVAudioUnitReverbPreset: @retroactive QueryBindable {}

private let log = Logger(category: "ReverbConfig")
