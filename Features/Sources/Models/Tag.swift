// Copyright © 2024 Brad Howes. All rights reserved.

import Foundation
import SwiftData

public typealias Tag = SchemaV1.Tag

public enum TagError: Error {
  case duplicateTag(name: String)
}

extension SchemaV1 {
  
  @Model
  public final class Tag {
    public var name: String = ""
    public var tagged: [SoundFont] = []

    public init(name: String) {
      self.name = name
    }
  }
}

extension ModelContext {

  @MainActor
  func findTag(name: String) -> Tag? {
    let fetchDescriptor: FetchDescriptor<Tag> = .init(predicate: #Predicate { $0.name == name })
    guard let result = try? fetch(fetchDescriptor) else {
      return nil
    }
    return result[0]
  }

  @MainActor
  func findTag(id: PersistentIdentifier) -> Tag? {
    let fetchDescriptor: FetchDescriptor<Tag> = .init(predicate: #Predicate { $0.persistentModelID == id })
    guard let result = try? fetch(fetchDescriptor) else {
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
