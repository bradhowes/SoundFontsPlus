// Copyright © 2025 Brad Howes. All rights reserved.

import BaseSupport
import SF2Resources
import SQLiteData
import Tagged

/**
 A tag is used to group or categorize a collection of SoundFont entries. There are four predefined (ubiquitous) tags:

 - `all` -- every SoundFont is a member of this collection
 - `builtIn` -- the four SoundFont files embedded with the app is a member of this collection
 - `added` -- every SoundFont added by the user is a member of this collection (initially empty)
 - `external` -- every SoundFont added but not copied to the app's document storage is a member of this collection

 A user can create additional tags via the app UI, and SoundFont membership with these custom tags is under their
 control. The four tags above are managed by the app -- the user cannot affect their membership outside of adding and
 deleting SF2 files.
 */
@Table
public struct FontTag {
  public typealias ID = Tagged<Self, Int64>

  /**
   The tags that exist in the app from the start. They also have predefined IDs so it is important that they are
   created first before any user tags.
   */
  public enum Ubiquitous: CaseIterable {
    /// All soundfonts
    case all
    /// Soundfonts delivered with the application
    case builtIn
    /// All soundfonts added by the user
    case added
    /// Soundfonts added to the shared documents directory on the device
    case device
    /// Soundfonts added but not copied to shared documents directory (iCloud or external drive)
    case external

    /// - returns: display name for the ubiquitous tag
    public var displayName: String {
      switch self {
      case .all: return "All"
      case .builtIn: return "Built-in"
      case .added: return "Added"
      case .device: return "Device"
      case .external: return "External"
      }
    }

    /// - returns: the zero-based index value for the ubiquitous tag
    private var tagIndex: Int {
      switch self {
      case .all: return 0
      case .builtIn: return 1
      case .added: return 2
      case .device: return 3
      case .external: return 4
      }
    }

    /// - returns: unique ID for the ubiquitous tag
    public var id: ID { .init(rawValue: .init(tagIndex + 1)) }
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

extension FontTag {

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

extension FontTag {

  /**
   Fetch the row for a given ID.

   - parameter id: the tag ID to look for
   - returns: the value found or `nil`.
   */
  public static func with(id: FontTag.ID?) -> FontTag? {
    guard let id else { return nil }
    return withDatabaseReader { db in
      try Self.all
        .find(id)
        .fetchOne(db)
    } ?? nil
  }

  public static func make(displayName: String) throws -> FontTag {
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
      Draft(displayName: newName, ordering: existingNames.count)
    }.returning(\.self)

    @Dependency(\.defaultDatabase) var database
    let result: [Self] = try database.write { try insertTag.fetchAll($0) }
    return result[0]
  }

  public static var tagsQuery: Select<(), FontTag, ()> {
    Self.all
      .order(by: \.ordering)
  }

  public static var tags: [Self] {
    withDatabaseReader { try tagsQuery.fetchAll($0) } ?? []
  }

  public func delete() throws {
    try Self.delete(id: self.id)
  }

  public static func delete(id: FontTag.ID) throws {
    guard id.isUserDefined else { throw ModelError.deleteUbiquitous(name: id.displayName ?? "???") }
    withDatabaseWriter {
      try Self.delete()
        .where { $0.id.eq(id) }
        .execute($0)
    }
  }

  static func reorder(tagIds: [FontTag.ID]) throws {
    @Dependency(\.defaultDatabase) var database
    try database.write { db in
      for tagId in tagIds.enumerated() {
        try FontTag
          .find(tagId.1)
          .update { $0.ordering = tagId.0 }
          .execute(db)
      }
    }
  }

  func rename(new displayName: String) throws {
    guard self.isUserDefined else { throw ModelError.renameUbiquitous(name: self.displayName) }
    let trimmed = displayName.trimmedOfWhitespaces
    guard !trimmed.isEmpty else { throw ModelError.emptyTagName }

    @Dependency(\.defaultDatabase) var database
    let existing = try database.read {
      try Self.select(\.displayName).where({$0.displayName == displayName}).fetchAll($0)
    }
    guard existing.isEmpty else { throw ModelError.duplicateTag(name: displayName) }

    try database.write { db in
      try FontTag
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

extension FontTag.ID {

  public var isUbiquitous: Bool {
    guard let last = Tag.Ubiquitous.allCases.last else { fatalError() }
    return self > 0 && self <= last.id
  }

  public var isUserDefined: Bool { !self.isUbiquitous }

  public var displayName: String? {
    for each in Tag.Ubiquitous.allCases where each.id == self {
      return each.displayName
    }
    return nil
  }
}

extension FontTag: Hashable, Identifiable, Sendable {}

extension FontTag.Draft: Equatable, Sendable {}

extension SF2ResourceTag: Identifiable {
  public var id: SoundFont.ID { .init(rawValue: Int64(self.rawValue)) }
}
