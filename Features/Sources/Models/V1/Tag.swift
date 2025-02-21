// Copyright © 2025 Brad Howes. All rights reserved.

import Foundation
import Dependencies
import GRDB
import Tagged

public struct Tag: Codable, Identifiable, FetchableRecord, MutablePersistableRecord {
  public typealias ID = Tagged<Self, Int64>

  public enum Ubiquitous: Codable, CaseIterable {
    /// Tag that represents all SoundFont entities
    case all
    /// Tag that represents built-in SoundFont entities
    case builtIn
    /// Tag that represents all user-installed entities
    case added
    /// Tag that represents all external entities (subset of `added`)
    case external

    /// The display name of the tag
    public var name: String {
      switch self {
      case .all: return "All"
      case .builtIn: return "Built-in"
      case .added: return "Added"
      case .external: return "External"
      }
    }

    public var id: ID {
      switch self {
      case .all: return .init(1)
      case .builtIn: return .init(2)
      case .added: return .init(3)
      case .external: return .init(4)
      }
    }
  }

  public let id: ID
  public var name: String
  public var ordering: Int

  public var isUbiquitous: Bool { id.rawValue < Ubiquitous.allCases.count }
  public var isUserDefined: Bool { !isUbiquitous }

  public static func make(_ db: Database, name: String) throws -> Tag {
    try PendingTag(name: name, ordering: Tag.fetchCount(db)).insertAndFetch(db, as: Tag.self)
  }

  static func make(_ db: Database, name: String, ordering: Int) throws -> Tag {
    try PendingTag(name: name, ordering: ordering).insertAndFetch(db, as: Tag.self)
  }
}

private struct PendingTag: Codable, PersistableRecord {
  let name: String
  let ordering: Int

  static let databaseTableName = Tag.databaseTableName
}

extension Tag: Sendable {}

extension Tag: TableCreator {
  enum Columns {
    static let id = Column(CodingKeys.id)
    static let name = Column(CodingKeys.name)
    static let ordering = Column(CodingKeys.ordering)
  }

  static func createTable(in db: Database) throws {
    try db.create(table: databaseTableName) { table in
      table.autoIncrementedPrimaryKey(Columns.id)
      table.column(Columns.name, .text).notNull()
      table.column(Columns.ordering, .integer).notNull()
    }

    for tag in Ubiquitous.allCases.enumerated() {
      _ = try Tag.make(_: db, name: tag.1.name, ordering: tag.0)
    }
  }
}

// MARK: TaggedSoundFont association
extension Tag {
  static let taggedSoundFonts = hasMany(TaggedSoundFont.self)
}

// MARK: SoundFont association
extension Tag {
  static let soundFonts = hasMany(SoundFont.self, through: taggedSoundFonts, using: TaggedSoundFont.soundFont)

  public var soundFonts: QueryInterfaceRequest<SoundFont> { request(for: Self.soundFonts) }
}
