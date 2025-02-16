// Copyright © 2024 Brad Howes. All rights reserved.

import Foundation
import Engine
import GRDB
import IdentifiedCollections
import Tagged

public struct SoundFont: Codable, Identifiable, FetchableRecord, MutablePersistableRecord {
  public typealias ID = Tagged<SoundFont, Int64>

  public let id: ID
  public var displayName: String

  private let kind: Location.Kind
  private let url: URL?
  private let raw: Data?

  public let originalName: String
  public let embeddedName: String
  public let embeddedComment: String
  public let embeddedAuthor: String
  public let embeddedCopyright: String
  public var notes: String

  public var location: Location { .init(kind: kind, url: url, raw: raw) }
  public var source: SoundFontKind? { try? .init(location: location) }
}

extension SoundFont: Sendable {

  /// Create a new SoundFont entry for a file.
  public static func make(
    in db: Database,
    displayName: String,
    location: Location
  ) throws -> SoundFont {
    guard let fileInfo = location.fileInfo else {
      throw ModelError.invalidLocation(name: location.description)
    }

    let soundFont = try PendingSoundFont(
      displayName: displayName,
      kind: location.kind,
      url: location.url,
      raw: location.raw,
      originalName: displayName,
      embeddedName: String(fileInfo.embeddedName()),
      embeddedComment: String(fileInfo.embeddedComment()),
      embeddedAuthor: String(fileInfo.embeddedAuthor()),
      embeddedCopyright: String(fileInfo.embeddedCopyright()),
      notes: ""
    ).insertAndFetch(db, as: SoundFont.self)

    for presetIndex in 0..<fileInfo.size() {
      try Preset.make(in: db, soundFont: soundFont.id, index: presetIndex, presetInfo: fileInfo[presetIndex])
    }

    for tagId in location.tagIds {
      _ = try TaggedSoundFont(soundFontId: soundFont.id, tagId: tagId).insertAndFetch(db)
    }

    return soundFont
  }
}

extension SoundFont: TableCreator {
  enum Columns {
    static let id = Column(CodingKeys.id)
    static let displayName = Column(CodingKeys.displayName)
    static let kind = Column(CodingKeys.kind)
    static let url = Column(CodingKeys.url)
    static let raw = Column(CodingKeys.raw)
    static let originalName = Column(CodingKeys.originalName)
    static let embeddedName = Column(CodingKeys.embeddedName)
    static let embeddedComment = Column(CodingKeys.embeddedComment)
    static let embeddedAuthor = Column(CodingKeys.embeddedAuthor)
    static let embeddedCopyright = Column(CodingKeys.embeddedCopyright)
    static let notes = Column(CodingKeys.notes)
  }

  static func createTable(in db: Database) throws {
    try db.create(table: databaseTableName) { table in
      table.autoIncrementedPrimaryKey(Columns.id)
      table.column(Columns.displayName, .text).notNull()
      table.column(Columns.kind, .text).notNull()
      table.column(Columns.url, .blob)
      table.column(Columns.raw, .blob)
      table.column(Columns.originalName, .text).notNull()
      table.column(Columns.embeddedName, .text).notNull()
      table.column(Columns.embeddedComment, .text).notNull()
      table.column(Columns.embeddedAuthor, .text).notNull()
      table.column(Columns.embeddedCopyright, .text).notNull()
      table.column(Columns.notes, .text).notNull()
    }
  }
}

extension SoundFont {

  /// Query to get all sound fonts in order of their name
  public static var all: QueryInterfaceRequest<Self> { all().order(Self.Columns.displayName) }

  /// Association of sound font to preset
  public static let presets = hasMany(Preset.self)

  /// Query to get all visible presets of sound font, ordered by index
  public var presets: QueryInterfaceRequest<Preset> {
    request(for: Self.presets).order(Preset.Columns.index).filter(Preset.Columns.visible)
  }

  /// Query to get all presets of sound font, ordered by index
  public var allPresets: QueryInterfaceRequest<Preset> {
    request(for: Self.presets).order(Preset.Columns.index)
  }

  /// Association of sound font to tagged table
  static let soundFontTags = hasMany(TaggedSoundFont.self)

  /// Association of sound font to tags
  static let tags = hasMany(Tag.self, through: soundFontTags, using: TaggedSoundFont.tag)

  /// Query to get all tags of a sound font.
  public var tags: QueryInterfaceRequest<Tag> {
    request(for: Self.tags).order(Tag.Columns.ordering) }
}

struct PendingSoundFont: Codable, FetchableRecord, PersistableRecord {
  let displayName: String
  let kind: Location.Kind
  let url: URL?
  let raw: Data?
  let originalName: String
  let embeddedName: String
  let embeddedComment: String
  let embeddedAuthor: String
  let embeddedCopyright: String
  let notes: String

  public static let databaseTableName = SoundFont.databaseTableName
}
