// Copyright © 2025 Brad Howes. All rights reserved.

import Dependencies
import Engine
import SharingGRDB
import Tagged

@Table
public struct Preset: Hashable, Identifiable, Sendable {
  public typealias ID = Tagged<Self, Int64>

  public let id: ID
  public let index: Int
  public let bank: Int
  public let program: Int
  public let originalName: String
  public let soundFontId: SoundFont.ID

  public var displayName: String
  public var visible: Bool
  public var notes: String
}

extension Preset {

  public var soundFontName: String {
    @Dependency(\.defaultDatabase) var database
    let query = SoundFont.find(self.soundFontId).select { $0.displayName }
    return (try? database.read { try query.fetchOne($0) }) ?? "???"
  }

  /// Obtain the `AudioConfig.Draft` value associated with this preset. If one does not exist, then
  /// return one with default values.
  public var audioConfig: AudioConfig.Draft {
    @Dependency(\.defaultDatabase) var database
    if let value = (try? database.read { db in
      let query = AudioConfig.all.where { $0.presetId.eq(self.id) }
      return try query.fetchOne(db)
    }) {
      return .init(value)
    }
    return AudioConfig.Draft(presetId: self.id)
  }

  static func migrate(_ migrator: inout DatabaseMigrator) {
    migrator.registerMigration(Self.tableName) { db in
      try #sql(
      """
      CREATE TABLE "\(raw: Self.tableName)" (
        "id" INTEGER PRIMARY KEY AUTOINCREMENT,
        "index" INTEGER NOT NULL,
        "bank" INTEGER NOT NULL,
        "program" INTEGER NOT NULL,
        "originalName" TEXT NOT NULL,
        "soundFontId" INTEGER NOT NULL,
        "displayName" TEXT NOT NULL,
        "visible" INTEGER NOT NULL CHECK ("visible" in (0, 1)),
        "notes" TEXT NOT NULL,
      
        FOREIGN KEY("soundFontId") REFERENCES "soundFonts"("id") ON DELETE CASCADE
      ) STRICT
      """
      )
      .execute(db)
    }
  }
}

extension Preset {

  public static var active: Preset? {
    @Shared(.activeState) var activeState
    guard let presetId = activeState.activePresetId else { return nil }
    let query = Preset.find(presetId)
    @Dependency(\.defaultDatabase) var database
    return (try? database.read { try query.fetchOne($0) })
  }

  public static var source: SoundFont.ID? {
    @Shared(.activeState) var activeState
    return activeState.presetSource
  }

  public static func with(key presetId: Preset.ID) -> Preset? {
    @Dependency(\.defaultDatabase) var database
    return try? database.read { try Preset.find(presetId).fetchOne($0) }
  }
}
