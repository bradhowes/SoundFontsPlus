// Copyright © 2025 Brad Howes. All rights reserved.

import Foundation
import Dependencies
import GRDB
import IdentifiedCollections
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

    static func isUbiquitous(id: ID) -> Bool {
      guard let last = Self.allCases.last else { fatalError() }
      return id <= last.id
    }
  }

  public let id: ID
  public var name: String
  public var ordering: Int

  public var isUbiquitous: Bool { id.rawValue <= Ubiquitous.allCases.count }
  public var isUserDefined: Bool { !isUbiquitous }

  public func willDelete(_ db: Database) throws {
    if isUbiquitous {
      throw ModelError.deleteUbiquitous(name: self.name)
    }
  }

  public static func make(_ db: Database, name: String) throws -> Tag {
    do {
      return try PendingTag(name: name, ordering: Tag.fetchCount(db)).insertAndFetch(db, as: Tag.self)
    } catch is DatabaseError {
      throw ModelError.duplicateTag(name: name)
    }
  }

  public static func make(_ db: Database) throws -> Tag {
    let existing = try Tag.order(Tag.Columns.ordering).fetchAll(db)
    let names = Set<String>(existing.map(\.name))
    var name = "New Tag"
    var index = 0
    while names.contains(name) {
      index += 1
      name = "New Tag \(index)"
    }
    return try make(db, name: name)
  }

  public static var ordered: IdentifiedArrayOf<Tag> {
    @Dependency(\.defaultDatabase) var database
    let found = try? database.read { db in
      try Tag.order(Tag.Columns.ordering).fetchAll(db)
    }
    print("Tag.ordered:", found ?? [])
    return .init(uncheckedUniqueElements: found ?? [])
  }

  public static func reorder(_ db: Database, tags: [Tag]) throws {
    for var tag in tags.enumerated() {
      try tag.1.updateChanges(db) { $0.ordering = tag.0 }
    }
  }

  public var soundFontsCount: Int {
    @Dependency(\.defaultDatabase) var database
    let count = try? database.read { try? self.soundFonts.fetchCount($0) }
    return count ?? 0
  }
}

private struct PendingTag: Codable, PersistableRecord {
  let name: String
  let ordering: Int

  static let databaseTableName = Tag.databaseTableName
}

extension Tag: Equatable, Hashable, Sendable {}

extension Tag: TableCreator {
  enum Columns {
    static let id = Column(CodingKeys.id)
    static let name = Column(CodingKeys.name)
    static let ordering = Column(CodingKeys.ordering)
  }

  static func createTable(in db: Database) throws {
    try db.create(table: databaseTableName, options: .ifNotExists) { table in
      table.autoIncrementedPrimaryKey(Columns.id)
      table.column(Columns.name, .text).notNull().unique()
      table.column(Columns.ordering, .integer).notNull()
    }
  }

  private static func make(_ db: Database, name: String, ordering: Int) throws -> Tag {
    try PendingTag(name: name, ordering: ordering).insertAndFetch(db, as: Tag.self)
  }
}

// MARK: TaggedSoundFont association
extension Tag {
  static let taggedSoundFonts = hasMany(TaggedSoundFont.self)
}

// MARK: SoundFont association
extension Tag {
  static let soundFonts = hasMany(SoundFont.self, through: taggedSoundFonts, using: TaggedSoundFont.soundFont)

  public var soundFonts: QueryInterfaceRequest<SoundFont> {
    request(for: Self.soundFonts)
  }
}
