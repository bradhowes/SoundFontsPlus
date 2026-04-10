// Copyright © 2025 Brad Howes. All rights reserved.

import BaseSupport
import Dependencies
import Sharing
import SQLiteData
import Tagged

/**
 Defines a sound font preset. Most of the read-only attributes come from the SF2 loaded into the application. A preset can be
 duplicated into a `favorite` which can have its own audio settings, or a preset can be hidden from view. Only a `favorite` row can
 be deleted by the user; otherwise the rows are removed only when the owning ``SoundFont`` entry is removed.

 Note that visibility is case of `Kind` and not an attribute of Preset.
 */
@Table
nonisolated public struct Preset {
  public typealias ID = Tagged<Self, Int64>

  public let id: ID
  public let index: Int
  public let bank: Int
  public let program: Int
  public let originalName: String
  public let soundFontId: SoundFont.ID

  public var displayName: String
  public var notes: String = ""

  /**
   Indicates the kind of preset a row represents. Be careful adding new values since the app should always work properly even if it
   sees a value that it does not understand.
   */
  public struct Kind {
    public let rawValue: Int

    public init(rawValue: Int) {
      self.rawValue = rawValue
    }

    public static let preset = Self(rawValue: 0)
    public static let favorite = Self(rawValue: 1)
    public static let hidden = Self(rawValue: -1)

    public static let allCases: [Self] = [.preset, .favorite, .hidden]

    public var unknown: Bool { !Self.allCases.contains(self) }
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
        "kind" INTEGER NOT NULL,
        "notes" TEXT NOT NULL,
        FOREIGN KEY("soundFontId") REFERENCES "\(raw: SoundFont.tableName)"("id") ON DELETE CASCADE
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

  /**
   Obtain the display name for the preset's owning sound font. This is only used when editing the preset meta data, so no need to
   optimize this query.
   */
  public var soundFontName: String {
    (withDatabaseReader { db in
      try SoundFont
        .find(self.soundFontId)
        .select { $0.displayName }
        .fetchOne(db)
    } ?? nil) ?? "???"
  }

  /// Obtain the `AudioConfig` value associated with this preset. If one does not exist, returns nil.
  public var audioConfig: AudioConfig? { AudioConfig.with(presetId: self.id) }

  /// Obtain an `AudioConfig.Draft` for the preset, creating one if necessary.
  public var audioConfigDraft: AudioConfig.Draft {
    guard let audioConfig = self.audioConfig else { return .init(presetId: self.id) }
    return .init(audioConfig)
  }

  /// Obtain the `DelayConfig` value associated with this config/preset. If one does not exist, returns `nil`.
  public var delayConfig: DelayConfig? { DelayConfig.with(presetId: self.id) }

  /**
   Obtain the `DelayConfig.Draft` value associated with this config/preset. If one does not exist, then return one with default
   values. Goal is to only save an entry when there is a deviation from the default values.
   */
  public var delayConfigDraft: DelayConfig.Draft {
    guard let delayConfig = self.delayConfig else { return .init(presetId: self.id) }
    return .init(delayConfig)
  }

  /// Obtain the `ReverbConfig` value associated with this config/preset. If one does not exist, returns `nil`.
  public var reverbConfig: ReverbConfig? { ReverbConfig.with(presetId: self.id) }

  /**
   Obtain the `ReverbConfig.Draft` value associated with this config/preset. If one does not exist, then return one with default
   values. Goal is to only save an entry when there is a deviation from the default values.
   */
  public var reverbConfigDraft: ReverbConfig.Draft {
    guard let reverbConfig = self.reverbConfig else { return .init(presetId: self.id) }
    return .init(reverbConfig)
  }
}

extension Preset {

  /**
   Create a duplicate of the Preset, cloning the associated AudioConfig, DelayConfig and ReverbConfig rows if they exist.

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

    let clone = withDatabaseWriter { db in
      try Self.insert {
        dupe
      }
      .returning(\.self)
      .fetchAll(db)
    }?.first

    if let clone {
      audioConfig?.clone(presetId: clone.id)
      delayConfig?.clone(presetId: clone.id)
      reverbConfig?.clone(presetId: clone.id)
    }

    return clone
  }

  /**
   Toggle the visibility of the preset (a favorite is always visible).
   */
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

  /// - returns: a name value that does not match any other preset in the presets of the sound font.
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
}

extension Preset {

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

  /**
   Obtain a query that returns the set of presets to show (unordered) for a given sound font ID. Honors the `showOnlyFavorites`
   setting.

   - parameter soundFontId: the sound font to query for
   - returns: a query showing the appropriate contents
   */
  public static func presetsQuery(for soundFontId: SoundFont.ID) -> Where<Self> {
    @Shared(.showOnlyFavorites) var showOnlyFavorites
    return Preset.all.where { $0.soundFontId.eq(soundFontId) } && (
      showOnlyFavorites
      ? .where { $0.kind.eq(Kind.favorite) }
      : .where { $0.kind.neq(Kind.hidden) }
    )
  }

  /**
   Obtain a query that returns an ordered collection of presets to show for a given sound font ID. Honors the `favoritesOnTop` and
   `sortPresetsByName` settings which affect the ordering.

   - parameter soundFontId: the sound font to query for
   - returns: the select query
   */
  public static func visibleQuery(for soundFontId: SoundFont.ID) -> Select<(), Self, ()> {
    @Shared(.showOnlyFavorites) var showOnlyFavorites
    @Shared(.favoritesOnTop) var favoritesOnTop
    @Shared(.sortPresetsByName) var sortPresetsByName
    let query = presetsQuery(for: soundFontId)
    if sortPresetsByName {
      return favoritesOnTop
      ? query
        .order { $0.kind.desc() }
        .order { $0.displayName }
      : query
        .order { $0.displayName }
        .order { $0.kind }
    } else {
      return favoritesOnTop
      ? query
        .order { $0.kind.desc() }
        .order { $0.index }
      : query
        .order { $0.index }
        .order { $0.kind }
    }
  }

  /**
   Execute a query to obtain the presets for a given sound font ID.

   - parameter soundFontId: the sound font to query for
   - returns: the collection of presets
   */
  public static func visible(for soundFontId: SoundFont.ID) -> [Preset] {
    return withDatabaseReader {
      try visibleQuery(for: soundFontId).fetchAll($0)
    } ?? []
  }

  /// - returns: query for all presets (no favorites).
  public static func allQuery(for soundFontId: SoundFont.ID) -> Select<(), Self, ()> {
    Self
      .all
      .where { $0.soundFontId.eq(soundFontId) }
      .where { $0.kind.neq(Kind.favorite) }
      .order(by: \.index)
  }
  /**
   Obtain the collection of presets for a given sound font ID. Does not perform any filtering of hidden presets. Used when editing
   preset visibility.

   - parameter soundFontId: the sound font to query for
   - returns: the collection of presets
   */
  public static func all(for soundFontId: SoundFont.ID) -> [Preset] {
    withDatabaseReader {
      try allQuery(for: soundFontId).fetchAll($0)
    } ?? []
  }
}

extension Preset.Kind: Hashable, QueryBindable, RawRepresentable, Sendable {}

extension Preset: Hashable, Identifiable, Sendable {}

private let log: Logger = .init(category: "Preset")
