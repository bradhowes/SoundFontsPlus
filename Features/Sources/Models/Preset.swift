// Copyright © 2024 Brad Howes. All rights reserved.

import AVFoundation
import Foundation
import SwiftData

public typealias Preset = SchemaV1.Preset

extension SchemaV1 {

  @Model
  public final class Preset {
    public var owner: SoundFont?
    public var index: Int = -1
    public var name: String = ""
    public var visible: Bool = true

    @Relationship(deleteRule: .cascade) public var info: PresetInfo?
    @Relationship(deleteRule: .cascade) public var audioSettings: AudioSettings?
    @Relationship(deleteRule: .cascade) public var favorites: [Favorite]?

    public init(owner: SoundFont, index: Int, name: String) {
      self.owner = owner
      self.index = index
      self.name = name
    }
  }
}

public extension ModelContext {

  /// TODO: remove when cascading is fixed
  @MainActor
  func delete(preset: Preset) {
    if let faves = preset.favorites {
      for favorite in faves {
        delete(favorite)
      }
    }
    delete(preset)
  }
}
