// Copyright © 2025 Brad Howes. All rights reserved.

import AVFoundation
import Dependencies
import GRDB
import Tagged

public struct Favorite: Codable, FetchableRecord, MutablePersistableRecord {
  public typealias ID = Tagged<Self, Int64>

  public let id: ID
  public var displayName: String
  public var notes: String

  public var audioConfig: AudioConfig?
  public var delayConfig: DelayConfig?
  public var reverbConfig: ReverbConfig?

  static func make(db: Database, preset: Preset) throws -> Favorite {
    try PendingFavorite(
      displayName: preset.displayName,
      notes: "",
      presetId: preset.id
    ).insertAndFetch(db, as: Favorite.self)
  }
}

extension Favorite: TableCreator {
  public static let preset = belongsTo(Preset.self)

  public var preset: QueryInterfaceRequest<Preset> {
    request(for: Self.preset)
  }

  enum Columns {
    static let id = Column(CodingKeys.id)
    static let displayName = Column(CodingKeys.displayName)
    static let notes = Column(CodingKeys.notes)
  }

  static func createTable(in db: Database) throws {
    try db.create(table: databaseTableName) { table in
      table.autoIncrementedPrimaryKey(Columns.id)
      table.column(Columns.displayName, .text).notNull()
      table.column(Columns.notes, .text).notNull()
      table.belongsTo(Preset.databaseTableName, onDelete: .cascade).notNull()
    }
  }
}

struct PendingFavorite: Codable, FetchableRecord, PersistableRecord {
  let displayName: String
  let notes: String
  let presetId: Preset.ID

  static let databaseTableName = Favorite.databaseTableName
}
