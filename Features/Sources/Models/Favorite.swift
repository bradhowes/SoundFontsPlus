// Copyright © 2024 Brad Howes. All rights reserved.

import AVFoundation
import Foundation
import SwiftData

public typealias Favorite = SchemaV1.Favorite

extension SchemaV1 {

  @Model
  public final class Favorite {
    public var preset: Preset?
    public var name: String?
    public var notes: String?

    @Relationship(deleteRule: .cascade) public var audioSettings: AudioSettings?

    public init(name: String, preset: Preset) {
      self.name = name
      self.preset = preset
    }
  }
}

public extension ModelContext {

  func createFavorite(name: String, preset: Preset) throws -> Favorite {
    let favorite = Favorite(name: name, preset: preset)
    insert(favorite)
    try save()
    return favorite
  }
}
