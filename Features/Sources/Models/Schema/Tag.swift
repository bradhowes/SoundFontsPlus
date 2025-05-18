// Copyright © 2025 Brad Howes. All rights reserved.

import SharingGRDB
import Tagged

@Table
public struct Tag: Hashable, Identifiable, Sendable {
  public typealias ID = Tagged<Self, Int64>

  public enum Ubiquitous: CaseIterable {
    case all
    case builtIn
    case added
    case external

    public var displayName: String {
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

    public static func isUbiquitous(id: ID) -> Bool { id.isUbiquitous }
    public static func isUserDefined(id: ID) -> Bool { !id.isUbiquitous }
  }

  public let id: ID
  public var displayName: String
  public var ordering: Int

  public var isUbiquitous: Bool { id.isUbiquitous }
  public var isUserDefined: Bool { id.isUserDefined }

  public func willDelete(_ db: Database) throws {
    if isUbiquitous {
      throw ModelError.deleteUbiquitous(name: self.displayName)
    }
  }
}

extension Tag {

  static func migrate(_ migrator: inout DatabaseMigrator) {
    migrator.registerMigration(Self.tableName) { db in
      try #sql(
      """
      CREATE TABLE "\(raw: Self.tableName)" (
        "id" INTEGER PRIMARY KEY AUTOINCREMENT,
        "displayName" TEXT NOT NULL,
        "ordering" INTEGER NOT NULL
      ) STRICT
      """
      )
      .execute(db)
    }
  }
}

extension Tag {

  static func create(displayName: String) throws -> Tag {
    let trimmed = displayName.trimmingCharacters(in: .whitespacesAndNewlines)
    guard !trimmed.isEmpty else { throw ModelError.emptyTagName }

    @Dependency(\.defaultDatabase) var database
    let existing = try database.read {
      try Self.select(\.displayName).where({$0.displayName == trimmed}).fetchAll($0)
    }
    guard existing.isEmpty else { throw ModelError.duplicateTag(name: trimmed) }

    let insertTag = Self.insert {
      ($0.displayName, $0.ordering)
    } select: {
      Self.select {
        (trimmed, $0.count())
      }
    }.returning(\.self)

    let result: [Self] = try database.write { try insertTag.fetchAll($0) }
    return result[0]
  }

  func delete() throws {
    guard self.isUserDefined else { throw ModelError.deleteUbiquitous(name: self.displayName) }
    try Self.delete(self.id)
  }

  static func delete(_ id: Tag.ID) throws {
    guard !id.isUbiquitous else { throw ModelError.deleteUbiquitous(name: id.displayName ?? "???") }
    @Dependency(\.defaultDatabase) var database
    withErrorReporting {
      try database.write { db in
        try Self.delete().where({ $0.id == id }).execute(db)
      }
    }
  }

  static func reorder(tags: [Tag]) throws {
    @Dependency(\.defaultDatabase) var database
    try database.write { db in
      for orderedTag in tags.enumerated() {
        try Tag
          .find(orderedTag.1.id)
          .update { $0.ordering = orderedTag.0 }
          .execute(db)
      }
    }
  }

  func rename(new displayName: String) throws {
    guard self.isUserDefined else { throw ModelError.renameUbiquitous(name: self.displayName) }
    let trimmed = displayName.trimmingCharacters(in: .whitespacesAndNewlines)
    guard !trimmed.isEmpty else { throw ModelError.emptyTagName }

    @Dependency(\.defaultDatabase) var database
    let existing = try database.read {
      try Self.select(\.displayName).where({$0.displayName == displayName}).fetchAll($0)
    }
    guard existing.isEmpty else { throw ModelError.duplicateTag(name: displayName) }

    withErrorReporting {
      try database.write { db in
        try Models.Tag
          .update {$0.displayName = displayName}
          .where({ $0.id == id })
          .execute(db)
      }
    }
  }
}

extension Tag.ID {

  public var isUbiquitous: Bool {
    guard let last = Tag.Ubiquitous.allCases.last else { fatalError() }
    return self <= last.id
  }

  public var isUserDefined: Bool { !self.isUbiquitous }

  public var displayName: String? {
    for each in Tag.Ubiquitous.allCases where each.id == self {
      return each.displayName
    }
    return nil
  }
}
