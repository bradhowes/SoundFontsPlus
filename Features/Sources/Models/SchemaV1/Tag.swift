// Copyright © 2024 Brad Howes. All rights reserved.

import ComposableArchitecture
import Foundation
import Dependencies
import SwiftData
import Tagged

extension SchemaV1 {

  @Model
  public final class TagModel {
    public typealias Key = Tagged<TagModel, UUID>

    public enum Ubiquitous: CaseIterable {
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

      public var key: Key {
        switch self {
        case .all: return .init(.init(0))
        case .builtIn: return .init(.init(1))
        case .added: return .init(.init(2))
        case .external: return .init(.init(3))
        }
      }
    }

    public var internalKey: UUID

    public var key: Key { .init(internalKey) }

    public var ordering: Int

    public var name: String {
      didSet {
        if self.ubiquitous {
          fatalError("attempt to change name of ubiquitous tag")
        }
      }
    }

    public var ubiquitous: Bool {
      didSet { fatalError("attempt to set read-only attribute")}
    }

    public var isUbiquitous: Bool { ubiquitous }
    public var isUserDefined: Bool { !ubiquitous }

    public var tagged: [SoundFontModel]
    public var orderedFonts: [SoundFontModel] { tagged.sorted(by: { $0.displayName < $1.displayName }) }

    public init(key: Key, ordering: Int, name: String, ubiquitous: Bool) {
      self.internalKey = key.rawValue
      self.ordering = ordering
      self.name = name
      self.ubiquitous = ubiquitous
      self.tagged = []
    }

    public func tag(soundFont: SoundFontModel) {
      tagged.append(soundFont)
    }

    static func fetchDescriptor(predicate: Predicate<TagModel>? = nil) -> FetchDescriptor<TagModel> {
      .init(predicate: predicate, sortBy: [SortDescriptor(\.ordering)])
    }
  }
}

extension SchemaV1.TagModel {

  private static func fetchOptional(key: Key) -> SchemaV1.TagModel? {
    @Dependency(\.modelContextProvider) var context
    return (try? context.fetch(fetchDescriptor(predicate: #Predicate { $0.internalKey == key.rawValue })))?.first
  }

  static func fetch(ubiquitous: Ubiquitous) -> SchemaV1.TagModel? {
    fetchOptional(key: ubiquitous.key)
  }

  public static func fetch(key: Key) throws -> SchemaV1.TagModel {
    @Dependency(\.modelContextProvider) var context
    return try context.fetch(fetchDescriptor(predicate: #Predicate { $0.internalKey == key.rawValue }))[0]
  }

  /**
   Obtain an ubiquitous Tag, creating if necessary.

   - parameter kind: which tag to fetch
   - returns: the Tag entity that was fetched/created
   - throws if unable to fetch or create
   */
  public static func ubiquitous(_ kind: SchemaV1.TagModel.Ubiquitous) throws -> SchemaV1.TagModel {
    if let found = fetch(ubiquitous: kind) {
      return found
    }

    try createUbiquitous()

    guard let found = fetch(ubiquitous: kind) else {
      throw ModelError.failedToFetch(name: kind.name)
    }

    return found
  }

  /**
   Create all ubiquitous Tag entities.

   - parameter wanted: which tag to return
   - returns: the Tag entity that was wanted
   - throws if unable to fetch or create
   */
  private static func createUbiquitous() throws {
    print("TagModel.createUbiquitous")
    @Dependency(\.modelContextProvider) var context

    for (index, ubiTag) in SchemaV1.TagModel.Ubiquitous.allCases.enumerated() {
      let tag = SchemaV1.TagModel(
        key: ubiTag.key,
        ordering: index,
        name: ubiTag.name,
        ubiquitous: true
      )
      context.insert(tag)
    }

    try context.save()
  }

  /**
   Create a new Tag entity with a given name

   - parameter name: the name to assign to the tag
   - returns: the new Tag entity
   - throws if unable to create or if there is an existiing Tag with the same name
   */
  public static func create(name: String) throws -> SchemaV1.TagModel {
    @Dependency(\.modelContextProvider) var context
    @Dependency(\.uuid) var uuid

    let count = try context.fetchCount(FetchDescriptor<TagModel>())
    let tag = Self(key: .init(uuid()), ordering: count, name: name, ubiquitous: false)
    context.insert(tag)
    try context.save()

    return tag
  }

  public static func tags() throws -> [SchemaV1.TagModel] {
    @Dependency(\.modelContextProvider) var context
    if let found = try? context.fetch(fetchDescriptor()),
       !found.isEmpty {
      return found
    }

    try createUbiquitous()

    guard let found = try? context.fetch(fetchDescriptor()),
          !found.isEmpty else {
      throw ModelError.failedToFetchAny
    }

    return found
  }

  public static func delete(key: Key) throws {
    @Dependency(\.modelContextProvider) var context
    let fetchDescriptor = TagModel.fetchDescriptor(predicate: #Predicate { $0.internalKey == key.rawValue })
    let found = try context.fetch(fetchDescriptor)

    if found.count == 1 {
      context.delete(found[0])
      try context.save()
    }
  }
}

extension SchemaV1.TagModel {

  public static func activeTag() -> TagModel {
    @Shared(.activeTagKey) var tagKey
    if let tag = try? fetch(key: tagKey) {
      return tag
    }

    if let tag = try? ubiquitous(.all) {
      return tag
    }

    fatalError("unexpected nil activeTag")
  }

  public static func tagsFor(kind: Location.Kind) throws -> [TagModel] {
    var ubiTags: [TagModel.Ubiquitous] = [.all]
    switch kind {
    case .builtin: ubiTags.append(.builtIn)
    case .installed: ubiTags.append(.added)
    case .external: ubiTags += [.added, .external]
    }

    var tags = try ubiTags.map { try ubiquitous($0) }

    let tag = activeTag()
    if tag.isUserDefined {
      tags.append(tag)
    }

    return tags
  }
}

extension PersistenceReaderKey where Self == CodableAppStorageKey<TagModel.Key> {
  public static var activeTagKey: Self {
    .init(.appStorage("activeTagKey"))
  }
}

extension PersistenceReaderKey where Self == PersistenceKeyDefault<CodableAppStorageKey<TagModel.Key>> {
  public static var activeTagKey: Self { PersistenceKeyDefault(.activeTagKey, TagModel.Ubiquitous.all.key) }
}

//
//extension SchemaV1.Tag : Identifiable {
//  public var id: PersistentIdentifier { persistentModelID }
//}
//
//extension PersistenceReaderKey {
//  static public func tagKey(_ key: String) -> Self where Self == ModelIdentifierStorageKey<Tag.ID?> {
//    ModelIdentifierStorageKey(key)
//  }
//}
//
//extension PersistenceReaderKey where Self == ModelIdentifierStorageKey<Tag.ID?> {
//  static public var activeTag: Self { tagKey("activeTag") }
//}
