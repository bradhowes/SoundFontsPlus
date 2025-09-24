// Copyright © 2025 Brad Howes. All rights reserved.

import Dependencies
import Engine
import Sharing
import SQLiteData
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

  public var isFavorite: Bool { kind == .favorite }

  public var soundFontName: String {
    withDatabaseReader { db in
      try SoundFont
        .find(self.soundFontId)
        .select { $0.displayName }
        .fetchAll(db)
    }?.first ?? "???"
  }

  /// Obtain the `AudioConfig` value associated with this preset. If one does not exist, then
  /// returns nil.
  public var audioConfig: AudioConfig? {
    withDatabaseReader { db in
      try AudioConfig
        .all
        .where { $0.presetId.eq(self.id) }
        .fetchAll(db)
    }?.first
  }

  /// Obtain an `AudioConfig.Draft` for the preset.
  public var audioConfigDraft: AudioConfig.Draft {
    guard let audioConfig = self.audioConfig else { return .init(presetId: self.id) }
    return .init(audioConfig)
  }

  /// Obtain the `DelayConfig.Draft` value associated with this config/preset. If one does not exist, then
  /// return one with default values. Goal is to only save an entry when there is a deviation from
  /// the default values.
  public var delayConfig: DelayConfig? {
    withDatabaseReader { db in
      try DelayConfig
        .all
        .where { $0.presetId.eq(self.id) }
        .fetchAll(db)
    }?.first
  }

  public var delayConfigDraft: DelayConfig.Draft {
    guard let delayConfig = self.delayConfig else { return .init(presetId: self.id) }
    return .init(delayConfig)
  }

  /// Obtain the `ReverbConfig.Draft` value associated with this config/preset. If one does not exist, then
  /// return one with default values. Goal is to only save an entry when there is a deviation from
  /// the default values.
  public var reverbConfig: ReverbConfig? {
    withDatabaseReader { db in
      try ReverbConfig.all
        .where { $0.presetId.eq(self.id) }
        .fetchAll(db)
    }?.first
  }

  public var reverbConfigDraft: ReverbConfig.Draft {
    guard let reverbConfig = self.reverbConfig else { return .init(presetId: self.id) }
    return .init(reverbConfig)
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
      displayName: self.uniqueName,
      notes: self.notes,
      kind: .favorite
    )

    guard let clone = withDatabaseWriter({ db in
      try Self.insert {
        dupe
      }
      .returning(\.self)
      .fetchAll(db)
    })?.first else {
      return nil
    }

    // Can this be done with key paths?

    if let audioConfig = self.audioConfig {
      _ = audioConfig.clone(presetId: clone.id)
    }

    if let delayConfig = self.delayConfig {
      _ = delayConfig.clone(presetId: clone.id)
    }

    if let reverbConfig = self.reverbConfig {
      _ = reverbConfig.clone(presetId: clone.id)
    }

    return clone
  }

  public mutating func toggleVisibility() {
    precondition(self.kind != .favorite)
    let kind: Kind = self.kind == .preset ? .hidden : .preset
    self.kind = kind
    withDatabaseWriter { db in
      try Self.find(self.id)
        .update { $0.kind = kind }
        .execute(db)
    }
  }

  public var uniqueName: String {
    let query = Preset.all
      .where { $0.soundFontId.eq(self.soundFontId) }
      .where { $0.index.eq(self.index) }
      .select { $0.displayName }
    let names = Set<String>(
      withDatabaseReader { db in
        try query.fetchAll(db)
      } ?? []
    )
    var index = 0
    var candidate = self.originalName + " copy"
    while names.contains(candidate) {
      index += 1
      candidate = self.originalName + " copy \(index)"
    }

    return candidate
  }

  public static var active: Preset.ID? {
    @Shared(.activeState) var activeState
    return activeState.activePresetId
  }

  public static var source: SoundFont.ID? {
    @Shared(.selectedSoundFontId) var selectedSoundFontId
    @Shared(.activeState) var activeState
    return selectedSoundFontId ?? activeState.activeSoundFontId
  }

  public static func with(id: Preset.ID) -> Preset? {
    withDatabaseReader { db in
      try Self.all
        .find(id)
        .fetchAll(db)
    }?.first
  }
}
