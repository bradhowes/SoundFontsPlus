// Copyright © 2025 Brad Howes. All rights reserved.

import BaseSupport
public import SQLiteData
public import Tagged

/// A preset tag. Useful for categorizing presets. Can be searched for.
@Table
nonisolated public struct PresetTag {
  public typealias ID = Tagged<Self, Int64>

  /// The unique ID associated with the tag
  public let id: ID
  /// The name shown for the tag
  public var displayName: String

  public init(id: ID, displayName: String) {
    self.id = id
    self.displayName = displayName
  }
}

extension PresetTag {

  static func migrate(_ migrator: inout DatabaseMigrator) {
    migrator.registerMigration(Self.tableName) { db in
      try #sql(
        """
        CREATE TABLE "\(raw: Self.tableName)" (
          "id" INTEGER PRIMARY KEY AUTOINCREMENT,
          "displayName" TEXT NOT NULL
        ) STRICT
        """
      )
      .execute(db)
    }
  }
}

extension PresetTag {

  /**
   Fetch the row for a given ID.

   - parameter id: the tag ID to look for
   - returns: the value found or `nil`.
   */
  public static func with(id: PresetTag.ID?) -> PresetTag? {
    guard let id else { return nil }
    return withDatabaseReader { db in
      try Self.all
        .find(id)
        .fetchOne(db)
    } ?? nil
  }

  /**
   Fetch the row for a given name.

   - parameter name: the tag name to look for
   - returns: the value found or `nil`.
   */
  public static func with(name: String) -> PresetTag? {
    tags.first(where: { $0.displayName == name })
  }

  public static func make(displayName: String) throws -> PresetTag {
    @Dependency(\.defaultDatabase) var database
    return try make(db: database, displayName: displayName)
  }

  public static func make(db: any DatabaseWriter, displayName: String) throws -> PresetTag {
    let base = displayName.trimmedOfWhitespaces
    if base.isEmpty {
      throw ModelError.emptyTagName
    }

    let existingNames = Set<String>(Self.tags.map { $0.displayName })
    var newName = base
    var index = 0
    while existingNames.contains(newName) {
      index += 1
      newName = base + " \(index)"
    }

    let insertTag = Self.insert {
      Draft(displayName: newName)
    }.returning(\.self)

    let result: [Self] = try db.write { try insertTag.fetchAll($0) }
    return result[0]
  }

  public static var tags: [Self] {
    withDatabaseReader {
      try Self.all
        .order(by: \.displayName)
        .fetchAll($0)
    } ?? []
  }

  public func delete() throws {
    try Self.delete(id: self.id)
  }

  public static func delete(id: PresetTag.ID) throws {
    withDatabaseWriter {
      try Self.delete()
        .where { $0.id.eq(id) }
        .execute($0)
    }
  }

  public func rename(new displayName: String) throws {
    let trimmed = displayName.trimmedOfWhitespaces
    guard !trimmed.isEmpty else { throw ModelError.emptyTagName }

    @Dependency(\.defaultDatabase) var database
    let existing = try database.read {
      try Self.select(\.displayName).where({ $0.displayName.eq(displayName) }).fetchAll($0)
    }
    guard existing.isEmpty else { throw ModelError.duplicateTag(name: displayName) }

    try database.write { db in
      try PresetTag
        .update { $0.displayName = displayName }
        .where({ $0.id.eq(id) })
        .execute(db)
    }
  }
}

extension PresetTag: Hashable, Identifiable, Sendable {}

extension PresetTag.Draft: Equatable, Sendable {

  public init(displayName: String) {
    self.displayName = displayName
  }
}
