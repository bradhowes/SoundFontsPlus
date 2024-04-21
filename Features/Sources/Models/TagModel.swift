// Copyright © 2024 Brad Howes. All rights reserved.

import Foundation
import SwiftData

@Model
public final class TagModel {

  static let all = TagModel(id: UInt8.max, name: "All")
  static let builtIn = TagModel(id: UInt8.max - 1, name: "Built-in")

  @Attribute(.unique) public let id: String
  public var name: String
  @Relationship(deleteRule: .nullify) public var tagged: [SoundFontModel]

  public init(id: UUID, name: String) {
    self.id = id.uuidString
    self.name = name
    self.tagged = []
  }

  static func registerConstants(in context: ModelContext) throws {
    context.insert(all)
    context.insert(builtIn)
    try context.save()
  }
}

public extension TagModel {
  private convenience init(id: UInt8, name: String) {
    self.init(id: UUID(uuid: (UInt8.max, UInt8.max, UInt8.max, UInt8.max, UInt8.max, UInt8.max, UInt8.max, UInt8.max,
                              UInt8.max, UInt8.max, UInt8.max, UInt8.max, UInt8.max, UInt8.max, UInt8.max, id)),
              name: name)
  }
}
