// Copyright © 2025 Brad Howes. All rights reserved.

import Dependencies
import Engine
import SharingGRDB
import SF2ResourceFiles
import Tagged

@Table
public struct SoundFont: Hashable, Identifiable, Sendable {
  public typealias ID = Tagged<Self, Int64>

  public let id: ID

  public enum Kind: String, CaseIterable, Sendable, QueryBindable {
    case builtin
    case installed
    case external
  }

  private let kind: Kind
  private let location: Data

  public let originalName: String
  public let embeddedName: String
  public let embeddedComment: String
  public let embeddedAuthor: String
  public let embeddedCopyright: String

  public var displayName: String
  public var notes: String
}

extension SoundFont {

  static func insert(_ db: Database, sf2: SF2ResourceFileTag) {
    withErrorReporting {
      let soundFontKind: SoundFontKind = .builtin(resource: sf2.url)
      let (kind, location) = try soundFontKind.data()
      let fileInfo = try soundFontKind.fileInfo()
      let insertSoundFontDraft = SoundFont.insert(
        SoundFont.Draft(
          kind: kind,
          location: location,
          originalName: sf2.name,
          embeddedName: String(fileInfo.embeddedName()),
          embeddedComment: String(fileInfo.embeddedComment()),
          embeddedAuthor: String(fileInfo.embeddedAuthor()),
          embeddedCopyright: String(fileInfo.embeddedCopyright()),
          displayName: sf2.name,
          notes: ""
        )
      ).returning(\.id)

      if let soundFontId = try insertSoundFontDraft.fetchOne(db) {
        print("*** soundFontId:", soundFontId)
        let checking = try SoundFont.all.fetchAll(db)
        print("checking.isEmpty:", checking.isEmpty)
        print("hcecking has soundFontId:", checking.map(\.id).contains(soundFontId))

        let taggedSoundFonts: [TaggedSoundFont] = soundFontKind.tagIds.map { tagId in
            .init(
              soundFontId: soundFontId,
              tagId: tagId
            )
        }
        try TaggedSoundFont.insert(taggedSoundFonts).execute(db)

        let presets: [Preset.Draft] = (0..<fileInfo.size()).map { presetIndex in
          let presetInfo = fileInfo[presetIndex]
          let displayName = String(presetInfo.name())
          return .init(
            index: presetIndex,
            bank: Int(presetInfo.bank()),
            program: Int(presetInfo.program()),
            originalName: displayName,
            soundFontId: soundFontId,
            displayName: displayName,
            visible: true,
            notes: ""
          )
        }

        try Preset.insert(presets).execute(db)
      }
    }
  }
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
        "location" BLOB,
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

//public struct SoundFont: Codable, Identifiable, FetchableRecord, MutablePersistableRecord {
//  public typealias ID = Tagged<SoundFont, Int64>
//
//  public let id: ID
//
//  public enum Kind: String, Codable, CaseIterable, Sendable {
//    case builtin
//    case installed
//    case external
//  }
//
//  private let kind: Kind
//  private let location: Data
//
//  public let originalName: String
//  public let embeddedName: String
//  public let embeddedComment: String
//  public let embeddedAuthor: String
//  public let embeddedCopyright: String
//
//  public var displayName: String
//  public var notes: String
//
//  public var isbuiltin: Bool { kind == .builtin }
//  public var isInstalled: Bool { kind == .installed }
//  public var isExternal: Bool { kind == .external }
//
//  @discardableResult
//  public static func make(_ db: Database, builtin: SF2ResourceFileTag) throws -> SoundFont {
//    return try make(db, displayName: builtin.name, soundFontKind: .builtin(resource: builtin.url))
//  }
//
//  @discardableResult
//  public static func make(
//    _ db: Database,
//    displayName: String,
//    soundFontKind: SoundFontKind
//  ) throws -> SoundFont {
//    let fileInfo = try soundFontKind.fileInfo()
//    let (kind, location) = try soundFontKind.data()
//    let soundFont = try PendingSoundFont(
//      displayName: displayName,
//      kind: kind,
//      location: location,
//      originalName: displayName,
//      embeddedName: String(fileInfo.embeddedName()),
//      embeddedComment: String(fileInfo.embeddedComment()),
//      embeddedAuthor: String(fileInfo.embeddedAuthor()),
//      embeddedCopyright: String(fileInfo.embeddedCopyright()),
//      notes: ""
//    ).insertAndFetch(db, as: SoundFont.self)
//
//    for presetIndex in 0..<fileInfo.size() {
//      try Preset.make(db, soundFontId: soundFont.id, index: presetIndex, presetInfo: fileInfo[presetIndex])
//    }
//
//    for tagId in soundFontKind.tagIds {
//      _ = try TaggedSoundFont(soundFontId: soundFont.id, tagId: tagId).insertAndFetch(db)
//    }
//
//    return soundFont
//  }
//
//  @discardableResult
//  public static func mock(
//    _ db: Database,
//    kind: Kind,
//    name: String,
//    presetNames: [String],
//    tags: [String]
//  ) throws -> SoundFont {
//    let tmp = try FileManager.default.newTemporaryURL()
//    try FileManager.default.copyItem(
//      at: SF2ResourceFileTag.rolandNicePiano.url,
//      to: tmp
//    )
//
//    let sfk: SoundFontKind = kind == .installed
//    ? SoundFontKind.installed(file: tmp)
//    : SoundFontKind.external(bookmark: .init(url: tmp, name: name))
//
//    let (kind, data) = try sfk.data()
//
//    let soundFont = try PendingSoundFont(
//      displayName: name,
//      kind: kind,
//      location: data,
//      originalName: name,
//      embeddedName: "Embedded Name",
//      embeddedComment: "Embedded Comment",
//      embeddedAuthor: "Embedded Author",
//      embeddedCopyright: "Embedded Copyright",
//      notes: "My Notes"
//    ).insertAndFetch(db, as: SoundFont.self)
//
//    // Logger.soundFonts.debug("Created mock SoundFont \(soundFont.id): \(name)")
//
//    for presetName in presetNames.enumerated() {
//      try Preset.mock(db, soundFontId: soundFont.id, name: presetName.1, index: presetName.0)
//      // Logger.soundFonts.debug("Created mock Preset \(presetName.1)")
//    }
//
//    for tagId in sfk.tagIds {
//      // Logger.soundFonts.debug("Adding tag \(tagId)")
//      _ = try TaggedSoundFont(soundFontId: soundFont.id, tagId: tagId).insertAndFetch(db)
//    }
//
//    for tagName in tags {
//      let tag = try Tag.make(db, name: tagName)
//      _ = try TaggedSoundFont(soundFontId: soundFont.id, tagId: tag.id).insertAndFetch(db)
//    }
//
//    return soundFont
//  }
//
//  public func source() throws -> SoundFontKind {
//    try SoundFontKind(kind: kind, location: location)
//  }
//
//  public var sourceKind: String { (try? source())?.description ?? "N/A" }
//  public var sourcePath: String { (try? source())?.path.absoluteString ?? "N/A" }
//
//  public var presets: [Preset] {
//    @Dependency(\.defaultDatabase) var database
//    do {
//      return try database.read { try self.visiblePresetsQuery.fetchAll($0) }
//    } catch {
//      fatalError("failed to fetch presets")
//    }
//  }
//
//  public var allPresets: [Preset] {
//    @Dependency(\.defaultDatabase) var database
//    do {
//      return try database.read { try self.allPresetsQuery.fetchAll($0) }
//    } catch {
//      fatalError("failed to fetch presets")
//    }
//  }
//
//  public var tags: [Tag] {
//    @Dependency(\.defaultDatabase) var database
//    do {
//      return try database.read { try self.tagsQuery.fetchAll($0) }
//    } catch {
//      fatalError("failed to fetch tags")
//    }
//  }
//}
//
//private struct PendingSoundFont: Codable, PersistableRecord {
//  let displayName: String
//  let kind: SoundFont.Kind
//  let location: Data
//  let originalName: String
//  let embeddedName: String
//  let embeddedComment: String
//  let embeddedAuthor: String
//  let embeddedCopyright: String
//  let notes: String
//
//  static let databaseTableName = SoundFont.databaseTableName
//}
//
//extension SoundFont: Equatable, Sendable {}
//
//extension SoundFont: TableCreator {
//
//  public enum Columns {
//    static let id = Column(CodingKeys.id)
//    static let displayName = Column(CodingKeys.displayName)
//    static let kind = Column(CodingKeys.kind)
//    static let location = Column(CodingKeys.location)
//    static let originalName = Column(CodingKeys.originalName)
//    static let embeddedName = Column(CodingKeys.embeddedName)
//    static let embeddedComment = Column(CodingKeys.embeddedComment)
//    static let embeddedAuthor = Column(CodingKeys.embeddedAuthor)
//    static let embeddedCopyright = Column(CodingKeys.embeddedCopyright)
//    static let notes = Column(CodingKeys.notes)
//  }
//
//  static func createTable(in db: Database) throws {
//    try db.create(table: databaseTableName, options: .ifNotExists) { table in
//      table.autoIncrementedPrimaryKey(Columns.id)
//      table.column(Columns.displayName, .text).notNull()
//      table.column(Columns.kind, .text).notNull()
//      table.column(Columns.location, .blob)
//      table.column(Columns.originalName, .text).notNull()
//      table.column(Columns.embeddedName, .text).notNull()
//      table.column(Columns.embeddedComment, .text).notNull()
//      table.column(Columns.embeddedAuthor, .text).notNull()
//      table.column(Columns.embeddedCopyright, .text).notNull()
//      table.column(Columns.notes, .text).notNull()
//    }
//  }
//}
//
//// MARK: Preset association
//extension SoundFont {
//
//  /// Association of sound font to preset
//  public static let presets = hasMany(Preset.self)
//
//  /// Query to get all visible presets of sound font, ordered by index
//  public var visiblePresetsQuery: QueryInterfaceRequest<Preset> {
//    request(for: Self.presets).order(Preset.Columns.index).filter(Preset.Columns.visible)
//  }
//
//  /// Query to get all presets of sound font, ordered by index
//  public var allPresetsQuery: QueryInterfaceRequest<Preset> {
//    request(for: Self.presets).order(Preset.Columns.index)
//  }
//}
//
//// MARK: Tag association
//extension SoundFont {
//
//  /// Association of sound font to tagged table
//  static let soundFontTags = hasMany(TaggedSoundFont.self)
//
//  /// Association of sound font to tags
//  static let tags = hasMany(Tag.self, through: soundFontTags, using: TaggedSoundFont.tag)
//
//  /// Query to get all tags of a sound font.
//  public var tagsQuery: QueryInterfaceRequest<Tag> { request(for: Self.tags).order(Tag.Columns.ordering) }
//
//  public var taggedQuery: QueryInterfaceRequest<TaggedSoundFont> { request(for: Self.soundFontTags) }
//}
