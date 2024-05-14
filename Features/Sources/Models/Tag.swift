// Copyright © 2024 Brad Howes. All rights reserved.

import Foundation
import Dependencies
import DependenciesAdditions
import SwiftData

public typealias Tag = SchemaV1.Tag

public enum TagError: Error {
  /// Thrown if attempting to create a tag with the same name as an existing one.
  case duplicateTag(name: String)
}

extension SchemaV1 {

  @Model
  public final class Tag {

    public enum Ubiquitous : CaseIterable {
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
      /// The key associated with the tag that holds the tag's persistent ID in UserDefaults
      public var userDefaultsKey: String {
        switch self {
        case .all: return "AllTagIdKey"
        case .builtIn: return "BuiltInTagIdKey"
        case .added: return "UserTagIdKey"
        case .external: return "ExternalTagIdKey"
        }
      }
    }

    public var name: String = ""
    public var tagged: [SoundFont] = []

    public init(name: String) {
      self.name = name
    }

    public func tag(soundFont: SoundFont) {
      tagged.append(soundFont)
    }
  }
}

public extension ModelContext {

  /**
   Obtain an ubiquitous Tag, creating if necessary.

   - parameter kind: which tag to fetch
   - returns: the Tag entity that was fetched/created
   - throws if unable to fetch or create
   */
  @MainActor
  func ubiquitousTag(_ kind: Tag.Ubiquitous) -> Tag {
    @Dependency(\.userDefaults) var userDefaults

    if let rawTagIdData = userDefaults.data(forKey: kind.userDefaultsKey),
       let tag: Tag = try? findExact(id: rawTagIdData.decodedValue()) {
      return tag
    }

    return createAllUbiquitousTags(wanted: kind)
  }

  /**
   Create all ubiquitous Tag entities.

   - parameter wanted: which tag to return
   - returns: the Tag entity that was wanted
   - throws if unable to fetch or create
   */
  @MainActor
  fileprivate func createAllUbiquitousTags(wanted: Tag.Ubiquitous) -> Tag {
    @Dependency(\.userDefaults) var userDefaults

    // Create all of the tags -- they will have temporary persistentModelID values until saved.
    let tags = Tag.Ubiquitous.allCases.map { kind in
      let tag = Tag(name: kind.name)
      self.insert(tag)
      return (kind: kind, tag: tag)
    }

    // Now tags have real and stable persistentModelID values
    do {
      try self.save()
      // Save all persistent tag IDs and return the one that was originally asked for
      return (try tags.compactMap { kind, tag in
        let key = kind.userDefaultsKey
        let value = try tag.persistentModelID.encodedValue()
        userDefaults.set(value, forKey: key)
        return kind == wanted ? tag : nil
      })[0]
    } catch {
      fatalError("Failed to save ubiquitous tags to storage.")
    }
  }

  /**
   Locate the tag with the given name

   - parameter name: the name to look for
   - returns: optional Tag entity that matches the given value
   */
  @MainActor
  func findTag(name: String) -> Tag? {
    let fetchDescriptor: FetchDescriptor<Tag> = .init(predicate: #Predicate { $0.name == name })
    guard 
      let result = try? fetch(fetchDescriptor),
      !result.isEmpty
    else {
      return nil
    }
    return result[0]
  }

  /**
   Create a new Tag entity with a given name

   - parameter name: the name to assign to the tag
   - returns: the new Tag entity
   - throws if unable to create or if there is an existiing Tag with the same name
   */
  @MainActor
  func createTag(name: String) throws -> Tag {
    if findTag(name: name) != nil {
      throw TagError.duplicateTag(name: name)
    }

    let tag = Tag(name: name)
    insert(tag)
    return tag
  }

  @MainActor
  func tags() throws -> [Tag] {
    return try fetch(FetchDescriptor<Tag>(sortBy: [SortDescriptor(\.name)]))
  }
}
