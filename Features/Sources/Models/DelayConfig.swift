// Copyright © 2025 Brad Howes. All rights reserved.

import AVFoundation
import BaseSupport
import Sharing
import SQLiteData
import Tagged

/**
 Configurations for the delay effect. A ``Preset`` may have one associated with it such that when the preset is active, the
 delay device receives the associated delay config settings.
 */
@Table
nonisolated public struct DelayConfig {
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

        FOREIGN KEY("presetId") REFERENCES "\(raw: Preset.tableName)"("id") ON DELETE CASCADE
      ) STRICT
      """
      )
      .execute(db)
    }
  }
}

extension DelayConfig {

  /**
   Fetch the configuration for the given preset ID.

   - parameter presetId: the preset ID to look for
   - returns: the value found or `nil`
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
   - returns: the DelayConfig from the database
   */
  @discardableResult
  public static func save(config: Draft) -> Self? {
    log.debug("saving \(config, privacy: .public)")
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
  @discardableResult
  public func clone(presetId: Preset.ID) -> Self? {
    var draft = Self.draft(for: presetId, cloning: .init(self))
    draft.enabled = self.enabled
    return Self.save(config: draft)
  }

  /**
   Create new or locate existing Draft for a given preset

   - parameter presetId: the Preset that owns the delay config
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
      time: clone.time,
      feedback: clone.feedback,
      cutoff: clone.cutoff,
      wetDryMix: clone.wetDryMix,
      enabled: false,
      presetId: presetId
    )
  }

  private static func fetchDraft(presetId: Preset.ID, clone: Draft, where: Where<Self>) -> Draft {
    withDatabaseReader { db in
      if let found = try `where`.fetchOne(db) {
        return .init(found)
      } else {
        return cloneDisabledDraft(clone, presetId: presetId)
      }
    } ?? cloneDisabledDraft(clone, presetId: presetId)
  }
}

extension DelayConfig: Hashable, Identifiable, Sendable {}

extension DelayConfig.Draft: Equatable, Sendable {}

extension DelayConfig.Draft: CustomStringConvertible {
  public var description: String {
    """
    <DelayConfig.Draft
      time=\(time)
      feedback=\(feedback)
      cutoff=\(cutoff)
      wetDryMix=\(wetDryMix)
      enabled=\(enabled)
      presetId=\(presetId)
    />
    """
  }
}

private let log: Logger = .init(category: "DelayConfig")
