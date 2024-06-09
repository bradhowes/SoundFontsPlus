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
  func ubiquitousTag(_ kind: Tag.Ubiquitous) -> Tag {
    let found = findTagByName(name: kind.name)
    if !found.isEmpty {
      return found[0]
    }

    createAllUbiquitousTags()

    return findTagByName(name: kind.name)[0]
  }

  /**
   Create all ubiquitous Tag entities.

   - parameter wanted: which tag to return
   - returns: the Tag entity that was wanted
   - throws if unable to fetch or create
   */
  func createAllUbiquitousTags() {
    for ubiTag in Tag.Ubiquitous.allCases {
      let tag = Tag(name: ubiTag.name)
      self.insert(tag)
    }

    do {
      try self.save()
    } catch {
      fatalError("Failed to save ubiquitous tags to storage.")
    }
  }

  /**
   Locate the tag with the given name

   - parameter name: the name to look for
   - returns: optional Tag entity that matches the given value
   */
  func findTagByName(name: String) -> [Tag] {
    let fetchDescriptor: FetchDescriptor<Tag> = .init(predicate: #Predicate { $0.name == name })
    return (try? fetch(fetchDescriptor)) ?? []
  }

  /**
   Create a new Tag entity with a given name

   - parameter name: the name to assign to the tag
   - returns: the new Tag entity
   - throws if unable to create or if there is an existiing Tag with the same name
   */
  @MainActor
  func createTag(name: String) throws -> Tag {
    if !findTagByName(name: name).isEmpty {
      throw TagError.duplicateTag(name: name)
    }

    let tag = Tag(name: name)
    insert(tag)
    return tag
  }

  func tags() -> [Tag] {
    let fetchDescriptor = FetchDescriptor<Tag>(sortBy: [SortDescriptor(\.name)])
    if let found = try? fetch(fetchDescriptor),
       !found.isEmpty {
      return found
    }

    createAllUbiquitousTags()

    guard let found = try? fetch(fetchDescriptor),
          !found.isEmpty else {
      fatalError("Unable to fetch any tags")
    }

    return found
  }
}

extension SchemaV1.Tag : Identifiable {
  public var id: PersistentIdentifier { persistentModelID }
}
