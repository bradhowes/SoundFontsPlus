// Copyright © 2025 Brad Howes. All rights reserved.

import BaseSupport
import SF2Resources
import SQLiteData
import Tagged

/// A tag is used to group or categorize a collection of SoundFont entries. There are four predefined (ubiquitous) tags:
///
/// - `all` -- every SoundFont is a member of this collection
/// - `builtIn` -- the four SoundFont files embedded with the app is a member of this collection
/// - `added` -- every SoundFont added by the user is a member of this collection (initially empty)
/// - `external` -- every SoundFont added but not copied to the app's document storage is a member of this collection
///
/// A user can create additional tags via the app UI, and SoundFont membership with these custom tags is under their
/// control. The four tags above are managed by the app -- the user cannot affect their membership outside of adding and
/// deleting SF2 files.
@Table
public struct Tag {
  public typealias ID = Tagged<Self, Int64>

  /**
   The tags that exist in the app from the start. They also have predefined IDs that are negative so they never will collide with
   user IDs which autoincrement from 1.
   */
  public struct Ubiquitous {
    public let rawValue: Int64
    /// All soundfonts
    public static let all = Self(rawValue: -1)
    /// Soundfonts delivered with the application
    public static let builtIn = Self(rawValue: -2)
    /// All soundfonts added by the user
    public static let added = Self(rawValue: -3)
    /// Soundfonts added to the shared documents directory on the device
    public static let device = Self(rawValue: -4)
    /// Soundfonts added but not copied to shared documents directory (iCloud or external drive)
    public static let external = Self(rawValue: -5)

    public static let allCases: [Self] = [.all, .builtIn, .added, .device, .external]

    public init(rawValue: Int64) {
      self.rawValue = rawValue
    }

    /// - returns: display name for the ubiquitous tag
    public var displayName: String? {
      switch rawValue {
      case Self.all.rawValue: return "All"
      case Self.builtIn.rawValue: return "Built-in"
      case Self.added.rawValue: return "Added"
      case Self.device.rawValue: return "Device"
      case Self.external.rawValue: return "External"
      default: return nil
      }
    }

    /// - returns: the zero-based index value for the ubiquitous tag
    private var tagIndex: Int64 { rawValue }

    /// - returns: unique ID for the ubiquitous tag
    public var id: ID { .init(rawValue: rawValue) }
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

  /**
   Fetch the row for a given ID.
  
   - parameter id: the tag ID to look for
   - returns: the value found or `nil`.
   */
  public static func with(id: Tag.ID?) -> Tag? {
    guard let id else { return nil }
    return withDatabaseReader { db in
      try Self.all
        .find(id)
        .fetchOne(db)
    } ?? nil
  }

  public static func make(displayName: String) throws -> Tag {
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

  public static var tagsQuery: Select<(), Tag, ()> {
    Self.all
      .order(by: \.ordering)
  }

  public static var tags: [Self] {
    withDatabaseReader { try tagsQuery.fetchAll($0) } ?? []
  }

  public func delete() throws {
    try Self.delete(id: self.id)
  }

  public static func delete(id: Tag.ID) throws {
    guard id.isUserDefined else { throw ModelError.deleteUbiquitous(name: id.displayName ?? "???") }
    withDatabaseWriter {
      try Self.delete()
        .where { $0.id.eq(id) }
        .execute($0)
    }
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
    let trimmed = displayName.trimmedOfWhitespaces
    guard !trimmed.isEmpty else { throw ModelError.emptyTagName }

    @Dependency(\.defaultDatabase) var database
    let existing = try database.read {
      try Self.select(\.displayName).where({ $0.displayName == displayName }).fetchAll($0)
    }
    guard existing.isEmpty else { throw ModelError.duplicateTag(name: displayName) }

    try database.write { db in
      try Tag
        .update { $0.displayName = displayName }
        .where({ $0.id == id })
        .execute(db)
    }
  }

  var soundFonts: [SoundFont] {
    let query =
      TaggedSoundFont
      .join(SoundFont.all) {
        $0.soundFontId.eq($1.id) && $0.tagId.eq(self.id)
      }
      .select {
        $1
      }

    @Dependency(\.defaultDatabase) var database
    let found =
      (try? database.read { db in
        try query.fetchAll(db)
      }) ?? []

    return found
  }
}

extension Tag.ID {

  public var isUbiquitous: Bool { self.rawValue < 0 }

  public var isUserDefined: Bool { !self.isUbiquitous }

  public var displayName: String? { Tag.Ubiquitous(rawValue: self.rawValue).displayName }
}

extension Tag.Ubiquitous: RawRepresentable, QueryBindable, Sendable {}

extension Tag: Hashable, Identifiable, Sendable {}

extension Tag.Draft: Equatable, Sendable {}

extension SF2ResourceTag: Identifiable {
  public var id: SoundFont.ID { .init(rawValue: Int64(self.rawValue)) }
}
