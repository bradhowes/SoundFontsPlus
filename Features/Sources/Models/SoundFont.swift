// Copyright © 2025 Brad Howes. All rights reserved.

import Dependencies
import Engine
import Foundation
import SF2Resources
import SQLiteData
import Tagged

/**
 Definition of a soundfont table that holds various pieces of information regarding soundfont files.
 A SoundFont entry contains various meta data attributes loaded from a SF2 file. Most of these attributes are not
 necessary for app usage. The `SoundFontEditor` feature is the only one that reveals this meta data. Usually, the app
 works with `SoundFontInfo` rows which is a slimmer view into the SoundFont table.
 */
@Table
nonisolated public struct SoundFont {
  public typealias ID = Tagged<Self, Int64>

  public let id: ID

  /**
   Indication of where the sound font file is located.

   - builtin -- the file resides in the application bundle
   - installed -- the file resides in an app group folder
   - external -- the file resides elsewhere and requires special effort to access
   */
  public struct Kind {
    public let rawValue: Int

    public init(rawValue: Int) {
      self.rawValue = rawValue
    }

    public static let builtin = Self(rawValue: 1)
    public static let installed = Self(rawValue: 2)
    public static let external = Self(rawValue: 3)

    public static let allCases: [Self] = [.builtin, .installed, .external]

    public var unknown: Bool { !Self.allCases.contains(self) }
  }

  public var displayName: String

  public let kind: Kind
  public let location: Data

  public let originalName: String
  public let embeddedName: String
  public let embeddedComment: String
  public let embeddedAuthor: String
  public let embeddedCopyright: String

  public var notes: String

  public var isBuiltin: Bool { kind == .builtin }
  public var isInstalled: Bool { kind == .installed }
  public var isExternal: Bool { kind == .external }
}

extension SoundFont {

  static func migrate(_ migrator: inout DatabaseMigrator) {
    migrator.registerMigration(Self.tableName) { db in
      try #sql(
      """
      CREATE TABLE "\(raw: Self.tableName)" (
        "id" INTEGER PRIMARY KEY AUTOINCREMENT,
        "displayName" TEXT NOT NULL,
        "kind" TEXT NOT NULL,
        "location" BLOB NOT NULL,
        "originalName" TEXT NOT NULL,
        "embeddedName" TEXT NOT NULL,
        "embeddedComment" TEXT NOT NULL,
        "embeddedAuthor" TEXT NOT NULL,
        "embeddedCopyright" TEXT NOT NULL,
        "notes" TEXT NOT NULL
      ) STRICT
      """
      )
      .execute(db)
    }
  }
}

extension SoundFont {

  /// Max number of presets to load during testing in order to reduce load times.
  public static var testSoundFontPresetLoadLimit: Int { 10 }

  /**
   Add a builtin soundfont to the database

   - parameter db: the database to update
   - parameter sf2: the tag of the soundfont to add
   - parameter limitedLoading: if true, limit number of presets added to soundFontPresetLoadLimit (testing only)
   */
  public static func addBuiltIn(_ db: Database, sf2: SF2ResourceTag, limitedLoading: Bool) throws {
    let soundFontKind: SoundFontKind = .builtin(tag: sf2)
    let fileInfo: SF2FileInfo = try soundFontKind.fileInfo()
    withErrorReporting {
      _ = try insertWithAssociations(
        db: db,
        insertion: try makeInsertion(soundFontKind: soundFontKind, name: sf2.name, fileInfo: fileInfo),
        fileInfo: fileInfo,
        tagIds: soundFontKind.tagIds,
        limitedLoading: limitedLoading
      )
    }
  }

  /// Search for a row with the given display name.
  /// - returns: `true` if a row exists.
  public static func exists(displayName: String) -> Bool {
    let found = withDatabaseReader { db in
      try SoundFont
        .where { $0.displayName.eq(displayName) }
        .select(\.id)
        .fetchAll(db)
    } ?? []
    return !found.isEmpty
  }

  /**
   Import an SF2 file, creating a new ``SoundFont`` entry, associated ``Preset`` entries, and ``TaggedSoundFont`` entries.

   - parameter displayName: the name to show in the views
   - parameter soundFontKind: the type and location of the file to import
   - returns: new ``SoundFont`` record
   */
  @discardableResult
  public static func add(displayName: String, soundFontKind: SoundFontKind) throws -> SoundFont {
    let fileInfo: SF2FileInfo = try soundFontKind.fileInfo()
    guard let value = withDatabaseWriter(
      { db in
        guard let value = try insertWithAssociations(
          db: db,
          insertion: try makeInsertion(
            soundFontKind: soundFontKind,
            name: displayName,
            fileInfo: fileInfo
          ),
        fileInfo: fileInfo,
        tagIds: soundFontKind.tagIds,
        limitedLoading: false
      ) else {
        throw ModelError.failedToInsertSoundFont(name: displayName)
      }
      return value
    }) else {
      throw ModelError.failedToInsertSoundFont(name: displayName)
    }
    return value
  }

  /**
   Delete a row with the give sound font ID.

   - parameter id: the ID of the row to delete
   */
  public static func delete(id: SoundFont.ID) {
    withDatabaseWriter { db in
      try Self.delete()
        .where { $0.id.eq(id) }
        .execute(db)
    }
  }

  private static func insertWithAssociations(
    db: Database,
    insertion: Insert<SoundFont, SoundFont>,
    fileInfo: SF2FileInfo,
    tagIds: [Tag.ID],
    limitedLoading: Bool
  ) throws -> SoundFont? {
    guard
      let soundFont = try insertion.fetchOne(db)
    else {
      return nil
    }

    try TaggedSoundFont.insert {
      tagIds.map { .init(soundFontId: soundFont.id, tagId: $0) }
    }.execute(db)

    try Preset.insert {
      makePresets(
        soundFontId: soundFont.id,
        fileInfo: fileInfo,
        limit: limitedLoading ? Swift.min(testSoundFontPresetLoadLimit, fileInfo.size()) : fileInfo.size()
      )
    }.execute(db)

    return soundFont
  }

  private static func makeInsertion(
    soundFontKind: SoundFontKind,
    name: String,
    fileInfo: SF2FileInfo
  ) throws -> Insert<SoundFont, SoundFont> {
    let (kind, location) = try soundFontKind.data()
    let fileInfo: SF2FileInfo = try soundFontKind.fileInfo()
    let embeddedName = String(fileInfo.embeddedName())
    let embeddedComment = String(fileInfo.embeddedComment())
    let embeddedAuthor = String(fileInfo.embeddedAuthor())
    let embeddedCopyright = String(fileInfo.embeddedCopyright())
    return SoundFont.insert {
      SoundFont.Draft(
        displayName: name,
        kind: kind,
        location: location,
        originalName: name,
        embeddedName: embeddedName,
        embeddedComment: embeddedComment,
        embeddedAuthor: embeddedAuthor,
        embeddedCopyright: embeddedCopyright,
        notes: ""
      )
    }.returning(\.self)
  }

  private static func makePresets(
    soundFontId: SoundFont.ID,
    fileInfo: SF2FileInfo,
    limit: Int
  ) -> [Preset.Draft] {
    (0..<limit)
      .map { ($0, fileInfo[$0]) }
      .map { (presetIndex: $0.0, presetInfo: $0.1, name: String($0.1.name())) }
      .map { presetIndex, presetInfo, name in
          .init(
            index: presetIndex,
            bank: Int(presetInfo.bank()),
            program: Int(presetInfo.program()),
            originalName: name,
            soundFontId: soundFontId,
            displayName: name,
            notes: "",
            kind: .preset
          )
      }
  }
}

extension SoundFont {

  /// - returns: ``SoundFontKind`` value from the attributes of this row.
  public func source() throws -> SoundFontKind {
    try SoundFontKind(kind: kind, location: location, displayName: self.displayName)
  }

  /// - returns: a description of the source
  public var sourceKind: String { (try? source())?.description ?? "N/A" }

  /// - returns: a path tothe source file
  public var sourcePath: String { (try? source())?.url.absoluteString ?? "N/A" }

  /**
   Fetch the row for a given ID.

   - parameter id: the sound font ID to look for
   - returns: the value found or `nil`.
   */
  public static func with(id: SoundFont.ID) -> SoundFont? {
    withDatabaseReader { db in
      try SoundFont.all
        .find(id)
        .fetchOne(db)
    } ?? nil
  }

  /// - returns: the collection of ``Tag`` rows associated with the sound font
  public var tags: [Tag] {
    withDatabaseReader { db in
      try TaggedSoundFont
        .join(Tag.all) {
          $0.tagId.eq($1.id) && $0.soundFontId.eq(self.id)
        }
        .select {
          $1
        }
        .fetchAll(db)
    } ?? []
  }

  /// - returns: the collection of ``Preset`` rows associated with the sound font.
  public var presets: [Preset] {
    withDatabaseReader { db in
      try Preset.all
        .order(by: \.index)
        .where { $0.soundFontId.eq(self.id) }
        .where { $0.kind.neq(Preset.Kind.hidden) }
        .fetchAll(db)
    } ?? []
  }

  /// - returns: the collection of ``Preset`` rows associated with the sound font
  public var allPresets: [Preset] {
    withDatabaseReader { db in
      try Preset.all
        .order(by: \.index)
        .where { $0.soundFontId.eq(self.id) }
        .where { $0.kind.neq(Preset.Kind.favorite) }
        .fetchAll(db)
    } ?? []
  }

  /// - returns: various counters for the sound font row
  public var elementCounts: (presetCount: Int, favoriteCount: Int, hiddenCount: Int) {
    // swiftlint:disable:previous large_tuple
    let found = withDatabaseReader { db in
      try Preset.select {
        (
          $0.id.count(filter: $0.kind.eq(Preset.Kind.preset)),
          $0.id.count(filter: $0.kind.eq(Preset.Kind.favorite)),
          $0.id.count(filter: $0.kind.eq(Preset.Kind.hidden))
        )
      }
      .where { $0.soundFontId.eq(self.id) }
      .fetchAll(db)
    }
    return (found ?? [(presetCount: 0, favoriteCount: 0, hiddenCount: 0)])[0]
  }
}

extension SoundFont {

  public static func link(soundFontId: SoundFont.ID, to tagId: Tag.ID) {
    guard !tagId.isUbiquitous else { return }

    let existing = withDatabaseReader { db in
      try TaggedSoundFont
        .where { $0.soundFontId.eq(soundFontId) }
        .where { $0.tagId.eq(tagId) }
        .fetchCount(db)
    } ?? 0

    guard existing == 0 else { return }

    withDatabaseWriter { db in
      try TaggedSoundFont.insert {
        .init(soundFontId: soundFontId, tagId: tagId)
      }
      .execute(db)
    }
  }

  public static func unlink(soundFontId: SoundFont.ID, from tagId: Tag.ID) {
    guard !tagId.isUbiquitous else { return }
    withDatabaseWriter { db in
      try TaggedSoundFont.all
        .delete()
        .where { $0.soundFontId.eq(soundFontId) && $0.tagId.eq(tagId) }
        .execute(db)
    }
  }
}

extension SoundFont.ID {
  public static var fluidFont: SoundFont.ID { SF2ResourceTag.fluidFont.soundFontId }
  public static var freeFont: SoundFont.ID { SF2ResourceTag.freeFont.soundFontId }
  public static var museScore: SoundFont.ID { SF2ResourceTag.museScore.soundFontId }
  public static var rolandNicePiano: SoundFont.ID { SF2ResourceTag.rolandNicePiano.soundFontId }
}

extension SoundFont.Kind: Equatable, Hashable, QueryBindable, RawRepresentable, Sendable {}

extension SoundFont: Hashable, Identifiable, Sendable {}
