// Copyright © 2024 Brad Howes. All rights reserved.

import ComposableArchitecture
import Foundation
import Dependencies
import SwiftData

extension SchemaV1 {

  @Model
  public final class TagModel {

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
    }

    public var name: String
    public var tagged: [SoundFontModel]

    public var orderedFonts: [SoundFontModel] { tagged.sorted(by: { $0.displayName < $1.displayName }) }

    public init(name: String) {
      self.name = name
      self.tagged = []
    }

    public func tag(soundFont: SoundFontModel) {
      tagged.append(soundFont)
    }


    static func fetchDescriptor(predicate: Predicate<TagModel>? = nil) -> FetchDescriptor<TagModel> {
      .init(predicate: predicate, sortBy: [SortDescriptor(\.name)])
    }
  }
}

public extension SchemaV1.TagModel {

  /**
   Obtain an ubiquitous Tag, creating if necessary.

   - parameter kind: which tag to fetch
   - returns: the Tag entity that was fetched/created
   - throws if unable to fetch or create
   */
  static func ubiquitous(_ kind: SchemaV1.TagModel.Ubiquitous) throws -> SchemaV1.TagModel {
    if let found = findByName(name: kind.name) {
      return found
    }

    try createUbiquitous()

    guard let found = findByName(name: kind.name) else {
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
  static func createUbiquitous() throws {
    @Dependency(\.modelContextProvider) var context
    for ubiTag in SchemaV1.TagModel.Ubiquitous.allCases {
      let tag = SchemaV1.TagModel(name: ubiTag.name)
      context.insert(tag)
    }

    try context.save()
  }

  /**
   Locate the tag with the given name

   - parameter name: the name to look for
   - returns: optional Tag entity that matches the given value
   */
  static func findByName(name: String) -> SchemaV1.TagModel? {
    @Dependency(\.modelContextProvider) var context
    return (try? context.fetch(fetchDescriptor(predicate: #Predicate { $0.name == name })))?.first
  }

  /**
   Create a new Tag entity with a given name

   - parameter name: the name to assign to the tag
   - returns: the new Tag entity
   - throws if unable to create or if there is an existiing Tag with the same name
   */
  static func create(name: String) throws -> SchemaV1.TagModel {
    @Dependency(\.modelContextProvider) var context
    if findByName(name: name) != nil {
      throw ModelError.duplicateTag(name: name)
    }

    let tag = Self(name: name)
    context.insert(tag)

    return tag
  }

  static func tags() throws -> [SchemaV1.TagModel] {
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
}

extension SchemaV1.TagModel {

  static func tagsFor(kind: Location.Kind) throws -> [TagModel] {
    var tags: [TagModel.Ubiquitous] = [.all]
    switch kind {
    case .builtin: tags.append(.builtIn)
    case .installed: tags.append(.added)
    case .external: tags += [.added, .external]
    }
    return try tags.map { try ubiquitous($0) }
  }
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
