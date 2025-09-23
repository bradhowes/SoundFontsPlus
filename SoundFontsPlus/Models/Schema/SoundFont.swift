// Copyright © 2025 Brad Howes. All rights reserved.

import Dependencies
import Engine
import SQLiteData
import Tagged

/**
 Definition of a soundfont table that holds various pieces of information regarding soundfont files.
 A SoundFont entry contains various meta data attributes loaded from a SF2 file. Most of these attributes are not
 necessary for app usage. The `SoundFontEditor` feature is the only one that reveals this meta data. Usually, the app
 works with `SoundFontInfo` rows which is a slimmer view into the SoundFont table.
 */
@Table
public struct SoundFont: Hashable, Identifiable, Sendable {
  public typealias ID = Tagged<Self, Int64>

  public let id: ID

  public enum Kind: String, CaseIterable, Sendable, QueryBindable {
    case builtin
    case installed
    case external
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

  public var isInstalled: Bool { kind == .installed }
  public var isExternal: Bool { kind == .external }
  public var isBuiltIn: Bool { kind == .builtin }
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
        "location" BLOB NOT NULL UNIQUE,
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

  public static func addBuiltIn(_ db: Database, sf2: SF2ResourceFileTag) throws {
    let soundFontKind: SoundFontKind = .builtin(resource: sf2.url)
    let fileInfo: SF2FileInfo = try soundFontKind.fileInfo()
    let soundFontDraft = try makeSoundFontDraft(soundFontKind: soundFontKind, name: sf2.name, fileInfo: fileInfo)

    withErrorReporting {
      try install(db: db, soundFontDraft: soundFontDraft, fileInfo: fileInfo, soundFontKind: soundFontKind)
    }
  }

  public static func add(displayName: String, soundFontKind: SoundFontKind) throws {
    let fileInfo: SF2FileInfo = try soundFontKind.fileInfo()
    let soundFontDraft = try makeSoundFontDraft(soundFontKind: soundFontKind, name: displayName, fileInfo: fileInfo)

    withDatabaseWriter { db in
      try install(db: db, soundFontDraft: soundFontDraft, fileInfo: fileInfo, soundFontKind: soundFontKind)
    }
  }

  public static func delete(id: SoundFont.ID) {
    withDatabaseWriter { db in
      try Self.delete()
        .where { $0.id.eq(id) }
        .execute(db)
    }
  }

  private static func install(
    db: Database,
    soundFontDraft: Insert<SoundFont, SoundFont.ID>,
    fileInfo: SF2FileInfo,
    soundFontKind: SoundFontKind
  ) throws {
    guard let soundFontId = try soundFontDraft.fetchOne(db) else { return }
    try TaggedSoundFont.insert {
      soundFontKind.tagIds.map { .init(soundFontId: soundFontId, tagId: $0) }
    }.execute(db)
    try Preset.insert {
      makePresets(soundFontId: soundFontId, fileInfo: fileInfo)
    }.execute(db)
  }

  private static func makeSoundFontDraft(
    soundFontKind: SoundFontKind,
    name: String,
    fileInfo: SF2FileInfo
  ) throws -> Insert<SoundFont, SoundFont.ID> {
    let (kind, location) = try soundFontKind.data()
    let fileInfo: SF2FileInfo = try soundFontKind.fileInfo()
    return SoundFont.insert {
      SoundFont.Draft(
        displayName: name,
        kind: kind,
        location: location,
        originalName: name,
        embeddedName: String(fileInfo.embeddedName()),
        embeddedComment: String(fileInfo.embeddedComment()),
        embeddedAuthor: String(fileInfo.embeddedAuthor()),
        embeddedCopyright: String(fileInfo.embeddedCopyright()),
        notes: ""
      )
    }.returning(\.id)
  }

  private static func makePresets(soundFontId: SoundFont.ID, fileInfo: SF2FileInfo) -> [Preset.Draft] {
    (0..<fileInfo.size())
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

  public func source() throws -> SoundFontKind { try SoundFontKind(kind: kind, location: location) }

  public var sourceKind: String { (try? source())?.description ?? "N/A" }

  public var sourcePath: String { (try? source())?.path.absoluteString ?? "N/A" }

  public var tags: [FontTag] {
    let query = TaggedSoundFont
      .join(FontTag.all) {
        $0.tagId.eq($1.id) && $0.soundFontId.eq(self.id)
      }
      .select {
        $1
      }

    return withDatabaseReader { db in
      try query.fetchAll(db)
    } ?? []
  }

  public var presets: [Preset] {
    let query = Preset.all
      .order(by: \.index)
      .where { $0.soundFontId.eq(self.id) }
      .where { $0.kind.neq(Preset.Kind.hidden) }

    return withDatabaseReader { db in
      try query.fetchAll(db)
    } ?? []
  }

  public var allPresets: [Preset] {
    let query = Preset.all
      .order(by: \.index)
      .where { $0.soundFontId.eq(self.id) }
      .where { $0.kind.neq(Preset.Kind.favorite) }
    return withDatabaseReader { db in
      try query.fetchAll(db)
    } ?? []
  }

  // swiftlint:disable:next large_tuple
  public var elementCounts: (presetCount: Int, favoriteCount: Int, hiddenCount: Int) {
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
