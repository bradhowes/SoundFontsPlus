// Copyright © 2025 Brad Howes. All rights reserved.

import Dependencies
import Sharing
import SQLiteData
import Tagged

/**
 Defines a sound font preset. Most of the read-only attributes come from the SF2 loaded into the application. A preset
 can be duplicated into a `favorite` which can have its own audio settings, or a preset can be hidden from view. Only an `favorite`
 row can be deleted by the user; otherwise the rows are removed only when the owning ``SoundFont`` entry is removed.
 */
@Table
public struct Preset {
  public typealias ID = Tagged<Self, Int64>

  public let id: ID
  public let index: Int
  public let bank: Int
  public let program: Int
  public let originalName: String
  public let soundFontId: SoundFont.ID

  public var displayName: String
  public var notes: String = ""

  @frozen
  public enum Kind: Int, CaseIterable, QueryBindable {
    case preset = 0
    case favorite = 1
    case hidden = 2
  }

  public var kind: Kind = .preset

  public init(
    id: ID,
    index: Int,
    bank: Int,
    program: Int,
    originalName: String,
    soundFontId: SoundFont.ID,
    displayName: String,
    notes: String = "",
    kind: Kind = .preset
  ) {
    self.id = id
    self.index = index
    self.bank = bank
    self.program = program
    self.originalName = originalName
    self.soundFontId = soundFontId
    self.displayName = displayName
    self.notes = notes
    self.kind = kind
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
        "displayName" TEXT NOT NULL COLLATE NOCASE,
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

  /// Determine if row represents a `favorite` or copy of a ``Preset``.
  public var isFavorite: Bool { kind == .favorite }

  /// Obtain the display name for the preset's owning sound font. This is only used when editing the preset meta data, so no
  /// need to optimize this query.
  public var soundFontName: String {
    (withDatabaseReader { db in
      try SoundFont
        .find(self.soundFontId)
        .select { $0.displayName }
        .fetchOne(db)
    } ?? nil) ?? "???"
  }

  /// Obtain the `AudioConfig` value associated with this preset. If one does not exist, returns nil.
  public var audioConfig: AudioConfig? {
    withDatabaseReader { db in
      try AudioConfig.all
        .where { $0.presetId.eq(self.id) }
        .fetchOne(db)
    } ?? nil
  }

  /// Obtain an `AudioConfig.Draft` for the preset, creating one if necessary.
  public var audioConfigDraft: AudioConfig.Draft {
    guard let audioConfig = self.audioConfig else { return .init(presetId: self.id) }
    return .init(audioConfig)
  }

  /// Obtain the `DelayConfig` value associated with this config/preset. If one does not exist, returns `nil`.
  public var delayConfig: DelayConfig? {
    withDatabaseReader { db in
      try DelayConfig
        .all
        .where { $0.presetId.eq(self.id) }
        .fetchOne(db)
    } ?? nil
  }

  /// Obtain the `DelayConfig.Draft` value associated with this config/preset. If one does not exist, then
  /// return one with default values. Goal is to only save an entry when there is a deviation from
  /// the default values.
  public var delayConfigDraft: DelayConfig.Draft {
    guard let delayConfig = self.delayConfig else { return .init(presetId: self.id) }
    return .init(delayConfig)
  }

  /// Obtain the `ReverbConfig` value associated with this config/preset. If one does not exist, returns `nil`.
  public var reverbConfig: ReverbConfig? {
    withDatabaseReader { db in
      try ReverbConfig.all
        .where { $0.presetId.eq(self.id) }
        .fetchOne(db)
    } ?? nil
  }

  /// Obtain the `ReverbConfig.Draft` value associated with this config/preset. If one does not exist, then
  /// return one with default values. Goal is to only save an entry when there is a deviation from
  /// the default values.
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
    var candidate = self.displayName + " copy"
    while names.contains(candidate) {
      index += 1
      candidate = self.displayName + " copy \(index)"
    }

    return candidate
  }

  /**
   Fetch the row for a given ID.

   - parameter id: the preset ID to look for
   - returns: the value found or `nil`.
   */
  public static func with(id: Preset.ID) -> Preset? {
    withDatabaseReader { db in
      try Self.all
        .find(id)
        .fetchOne(db)
    } ?? nil
  }
}

extension Preset: Hashable, Identifiable, Sendable {}
