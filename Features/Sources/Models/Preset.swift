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
    @Relationship(deleteRule: .cascade, inverse: \Favorite.preset) public var favorites: [Favorite]?

    public init(owner: SoundFont, index: Int, name: String) {
      self.owner = owner
      self.index = index
      self.name = name
    }
  }
}

public extension ModelContext {

  /**
   Obtain the collection of presets for a given SoundFont entity. The presets will be ordered by their `index` value.

   - parameter soundFont: the SoundFont to query for
   - returns: the array of Presets entities
   */
  @MainActor
  func orderedPresets(for soundFont: SoundFont) throws -> [Preset] {
    let ownerId = soundFont.persistentModelID
    let fetchDescriptor = FetchDescriptor<Preset>(predicate: #Predicate { $0.owner?.persistentModelID == ownerId },
                                                  sortBy: [SortDescriptor(\.index)])
    return try fetch(fetchDescriptor)
  }

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
