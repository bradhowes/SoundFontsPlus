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

    public var allTagsIndex: Int {
      switch self {
      case .all: return 0
      case .builtIn: return 1
      case .added: return 2
      case .external: return 3
      }
    }

    public var id: ID { .init(rawValue: .init(allTagsIndex + 1)) }
  }

  public let id: ID
  public var displayName: String
  public var ordering: Int

  public var isUbiquitous: Bool { id.isUbiquitous }
  public var isUserDefined: Bool { id.isUserDefined }

  public init(id: ID, displayName: String, ordering: Int) {
    self.id = id
    self.displayName = displayName
    self.ordering = ordering
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

  public static func make(displayName: String) throws -> Tag {
    let base = displayName.trimmingCharacters(in: .whitespacesAndNewlines)
    if base.isEmpty {
      throw ModelError.emptyTagName
    }

    let existingNames = Set<String>(Self.ordered.map { $0.displayName })
    var newName = base
    var index = 0
    while existingNames.contains(newName) {
      index += 1
      newName = base + " \(index)"
    }

    let insertTag = Self
      .insert(Self.Draft(displayName: newName, ordering: existingNames.count))
      .returning(\.self)

    @Dependency(\.defaultDatabase) var database
    let result: [Self] = try database.write { try insertTag.fetchAll($0) }
    return result[0]
  }

  public static func with(key tagId: Tag.ID) -> Self? {
    @Dependency(\.defaultDatabase) var database
    return try? database.read { try Self.find(tagId).fetchOne($0) }
  }

  public func delete() throws {
    guard self.isUserDefined else { throw ModelError.deleteUbiquitous(name: self.displayName) }
    try Self.delete(id: self.id)
  }

  public static func delete(id: Tag.ID) throws {
    guard !id.isUbiquitous else { throw ModelError.deleteUbiquitous(name: id.displayName!) }
    @Dependency(\.defaultDatabase) var database
    try database.write { db in
      try Self.delete().where({ $0.id == id }).execute(db)
    }
  }

  public static var ordered: [Tag] {
    let query = Operations.tagsQuery
    @Dependency(\.defaultDatabase) var database
    return (try? database.read { try query.fetchAll($0) }) ?? []
  }

  static func reorder(tagIds: [Tag.ID]) throws {
    @Dependency(\.defaultDatabase) var database
    try database.write { db in
      for tagId in tagIds.enumerated() {
        try Tag
          .find(tagId.1)
          .update { $0.ordering = tagId.0 }
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

    try database.write { db in
      try Tag
        .update {$0.displayName = displayName}
        .where({ $0.id == id })
        .execute(db)
    }
  }

  var soundFonts: [SoundFont] {
    let query = TaggedSoundFont
      .join(SoundFont.all) {
        $0.soundFontId.eq($1.id) && $0.tagId.eq(self.id)
      }
      .select {
        $1
      }

    @Dependency(\.defaultDatabase) var database
    let found = (try? database.read { db in
      try query.fetchAll(db)
    }) ?? []

    return found
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
