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
  public var notes: String = ""

  public enum Kind: Int, CaseIterable, Sendable, QueryBindable {
    case preset = 0
    case favorite = 1
    case hidden = 2
  }

  public var kind: Kind = .preset
}

extension Preset {

  public var soundFontName: String {
    @Dependency(\.defaultDatabase) var database
    let query = SoundFont.find(self.soundFontId).select { $0.displayName }
    return (try? database.read { try query.fetchOne($0) }) ?? "???"
  }

  /// Obtain the `AudioConfig` value associated with this preset. If one does not exist, then
  /// returns nil.
  public var audioConfig: AudioConfig? {
    @Dependency(\.defaultDatabase) var database
    return (try? database.read { db in
      let query = AudioConfig.all.where { $0.presetId.eq(self.id) }
      return try query.fetchOne(db)
    })
  }

  /// Obtain an `AudioConfig.Draft` for the preset.
  public var audioConfigDraft: AudioConfig.Draft {
    if let audioConfig = self.audioConfig {
      return .init(audioConfig)
    } else {
      return .init()
    }
  }
}

extension Preset {

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
        "kind" INTEGER NOT NULL CHECK ("kind" in (0, 1, 2)),
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

  /**
   Create a duplicate of the Preset, cloning the associated AudioConfig, DelayConfig and ReverbConfig rows if they
   exist.

   - returns: cloned instance
   */
  @discardableResult
  public func clone() -> Self? {
    let dupe = Draft(
      index: self.index,
      bank: self.bank,
      program: self.program,
      originalName: self.originalName,
      soundFontId: self.soundFontId,
      displayName: self.displayName,
      notes: self.notes,
      kind: .favorite
    )

    @Dependency(\.defaultDatabase) var database
    guard let clone = (
      try? database.write {
        try Self.insert(dupe).returning(\.self).fetchOne($0)
      }
    ) else {
      return nil
    }

    if let audioConfig = self.audioConfig {
      _ = audioConfig.clone(presetId: clone.id)
    }

    return clone
  }

  public mutating func toggleVisibility() {
    precondition(self.kind != .favorite)
    let kind: Kind = self.kind == .preset ? .hidden : .preset
    self.kind = kind
    let query = Self.find(self.id).update { $0.kind = kind }
    @Dependency(\.defaultDatabase) var database
    try? database.write { try query.execute($0) }
  }

  public static var active: Preset? {
    @Shared(.activeState) var activeState
    guard let presetId = activeState.activePresetId else { return nil }
    return with(key: presetId)
  }

  public static var source: SoundFont.ID? {
    @Shared(.activeState) var activeState
    return activeState.presetSource
  }

  public static func with(key presetId: Preset.ID) -> Preset? {
    @Dependency(\.defaultDatabase) var database
    return try? database.read { try Preset.find(presetId).fetchOne($0) }
  }

  static let wherePreset = Self.where { $0.kind == Kind.preset }

  static let whereFavorite = Self.where { $0.kind == Kind.preset }

  static let whereVisible = Self.where { $0.kind != Kind.hidden }
}
