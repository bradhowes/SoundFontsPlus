// Copyright © 2025 Brad Howes. All rights reserved.

import CxxStdlib
import Dependencies
import Engine

public import Foundation
public import SF2Resources
public import SQLiteData
public import Tagged

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

   We could define this using a @Selection macro on an enum, but they all three share the same internal BLOB representation so we
   are sticking with this approach for now. The modeling is sound, though the coupling between the `Kind` value and the BLOB
   representation is not nearly as strong as it could be. Howver, we have only one BLOB location column instead of three, so...
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
  static public var indexedNameColumnIndexName: String { "\(tableName)-originalName" }

  static func migrate(_ migrator: inout DatabaseMigrator) {
    migrator.registerMigration(Self.tableName) { db in
      try #sql(
      """
      CREATE TABLE "\(raw: Self.tableName)" (
        "id" INTEGER PRIMARY KEY AUTOINCREMENT,
        "displayName" TEXT NOT NULL,
        "kind" INTEGER NOT NULL,
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

      try #sql(
      """
      CREATE INDEX IF NOT EXISTS "\(raw: Self.indexedNameColumnIndexName)" ON "\(raw: Self.tableName)" (
        "originalName"
      )
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
        displayName: sf2.name,
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
    let soundFont = withDatabaseWriter { db in
      try add(db: db, displayName: displayName, soundFontKind: soundFontKind)
    }

    if let soundFont {
      return soundFont
    }

    throw ModelError.failedToInsertSoundFont(name: displayName)
  }

  public static func add(db: Database, displayName: String, soundFontKind: SoundFontKind) throws -> SoundFont {
    let fileInfo: SF2FileInfo = try soundFontKind.fileInfo()
    return try insertWithAssociations(
      db: db,
      displayName: displayName,
      insertion: try makeInsertion(
        soundFontKind: soundFontKind,
        name: displayName,
        fileInfo: fileInfo
      ),
      fileInfo: fileInfo,
      tagIds: soundFontKind.tagIds,
      limitedLoading: false
    )
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

  // swiftlint:disable:next function_parameter_count
  private static func insertWithAssociations(
    db: Database,
    displayName: String,
    insertion: Insert<SoundFont, SoundFont>,
    fileInfo: borrowing SF2FileInfo,
    tagIds: [Tag.ID],
    limitedLoading: Bool
  ) throws -> SoundFont {
    guard
      let soundFont = try insertion.fetchOne(db)
    else {
      throw ModelError.failedToInsertSoundFont(name: displayName)
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

  // NOTE: this should not be necessary, but doing the simpler `String(value)` where value is a `std.string` fails to build
  // on Github (but not in Xcode on my laptop)
  private static func string<Bytes: Collection>(from bytes: Bytes) -> String where Bytes.Element == CChar {
    String(bytes: bytes.lazy.map { UInt8(bitPattern: $0) }, encoding: .utf8) ?? ""
  }

  private static func makeInsertion(
    soundFontKind: SoundFontKind,
    name: String,
    fileInfo: borrowing SF2FileInfo
  ) throws -> Insert<SoundFont, SoundFont> {
    let (kind, location) = try soundFontKind.data()
    let fileInfo: SF2FileInfo = try soundFontKind.fileInfo()
    return SoundFont.insert {
      SoundFont.Draft(
        displayName: name,
        kind: kind,
        location: location,
        originalName: name,
        embeddedName: string(from: fileInfo.embeddedName()),
        embeddedComment: string(from: fileInfo.embeddedComment()),
        embeddedAuthor: string(from: fileInfo.embeddedAuthor()),
        embeddedCopyright: string(from: fileInfo.embeddedCopyright()),
        notes: ""
      )
    }.returning(\.self)
  }

  private static func makePresets(
    soundFontId: SoundFont.ID,
    fileInfo: borrowing SF2FileInfo,
    limit: Int
  ) -> [Preset.Draft] {
    (0..<limit)
      .map { presetIndex in
        let presetInfo = fileInfo[presetIndex]
        let name = string(from: presetInfo.name())
        return .init(
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
    withDatabaseWriter { db in
      try TaggedSoundFont.insert {
        .init(soundFontId: soundFontId, tagId: tagId)
      } onConflictDoUpdate: { _ in }
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

extension SoundFont.Draft {
  public init(
    displayName: String,
    kind: SoundFont.Kind,
    location: Data,
    originalName: String,
    embeddedName: String,
    embeddedComment: String,
    embeddedAuthor: String,
    embeddedCopyright: String,
    notes: String
  ) {
    self.displayName = displayName
    self.kind = kind
    self.location = location
    self.originalName = originalName
    self.embeddedName = embeddedName
    self.embeddedComment = embeddedComment
    self.embeddedAuthor = embeddedAuthor
    self.embeddedCopyright = embeddedCopyright
    self.notes = notes
  }
}
