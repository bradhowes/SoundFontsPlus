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
  public var isBuiltin: Bool { kind == .builtin }
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
  public static var soundFontPresetLoadLimit: Int { 10 }

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

  public static func exists(displayName: String) -> Bool {
    let found = withDatabaseReader { db in
      try SoundFont
        .where { $0.displayName == displayName }
        .select(\.id)
        .fetchAll(db)
    } ?? []
    return !found.isEmpty
  }

  @discardableResult
  public static func add(displayName: String, soundFontKind: SoundFontKind) throws -> SoundFont {
    let fileInfo: SF2FileInfo = try soundFontKind.fileInfo()
    guard let value = withDatabaseWriter({ db in
      guard let value = try insertWithAssociations(
        db: db,
        insertion: try makeInsertion(soundFontKind: soundFontKind, name: displayName, fileInfo: fileInfo),
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
    tagIds: [FontTag.ID],
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
        limit: limitedLoading ? Swift.min(soundFontPresetLoadLimit, fileInfo.size()) : fileInfo.size()
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

  public func source() throws -> SoundFontKind {
    try SoundFontKind(kind: kind, location: location, displayName: self.displayName)
  }

  public var sourceKind: String { (try? source())?.description ?? "N/A" }

  public var sourcePath: String { (try? source())?.path.absoluteString ?? "N/A" }

  public static func with(id: SoundFont.ID) -> SoundFont? {
    withDatabaseReader { db in
      try SoundFont.all
        .find(id)
        .fetchAll(db)
    }?.first
  }

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

extension SoundFont.ID {
  public static var fluidFont: SoundFont.ID { SF2ResourceTag.fluidFont.soundFontId }
  public static var freeFont: SoundFont.ID { SF2ResourceTag.freeFont.soundFontId }
  public static var museScore: SoundFont.ID { SF2ResourceTag.museScore.soundFontId }
  public static var rolandNicePiano: SoundFont.ID { SF2ResourceTag.rolandNicePiano.soundFontId }
}
