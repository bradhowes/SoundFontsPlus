// Copyright © 2024 Brad Howes. All rights reserved.

import Foundation
import Dependencies
import DependenciesAdditions
import SwiftData

public typealias Tag = SchemaV1.Tag

public enum TagError: Error {
  case duplicateTag(name: String)
}

extension SchemaV1 {

  @Model
  public final class Tag {

    public enum Ubiquitous : CaseIterable {
      case all
      case builtIn

      var userDefaultsKey: String {
        switch self {
        case .all: return "AllTagIdKey"
        case .builtIn: return "BuiltInTagIdKey"
        }
      }

      var name: String {
        switch self {
        case .all: return "All"
        case .builtIn: return "Built-in"
        }
      }
    }

    public var name: String = ""
    public var tagged: [SoundFont] = []

    public init(name: String) {
      self.name = name
    }
  }
}

public extension ModelContext {

  @MainActor
  func ubiquitous(_ kind: Tag.Ubiquitous) throws -> Tag {
    @Dependency(\.userDefaults) var userDefaults
    if let rawTagIdData = userDefaults.data(forKey: kind.userDefaultsKey) {
      return try findTag(id: PersistentIdentifier.fromData(rawTagIdData))!
    }

    let tag = try createTag(name: kind.name)
    try save()
    try userDefaults.set(tag.persistentModelID.toData(), forKey: kind.userDefaultsKey)
    return tag
  }

  @MainActor
  func allTag() throws -> Tag {
    try ubiquitous(.all)
  }

  @MainActor
  func builtInTag() throws -> Tag {
    try ubiquitous(.builtIn)
  }

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

  @MainActor
  func findTag(id: PersistentIdentifier) -> Tag? {
    let fetchDescriptor: FetchDescriptor<Tag> = .init(predicate: #Predicate { $0.persistentModelID == id })
    guard
      let result = try? fetch(fetchDescriptor),
      !result.isEmpty 
    else {
      return nil
    }
    return result[0]
  }

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
