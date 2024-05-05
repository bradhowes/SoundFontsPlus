// Copyright © 2024 Brad Howes. All rights reserved.

import AVFoundation
import Foundation
import SwiftData

public typealias Favorite = SchemaV1.Favorite

extension SchemaV1 {

  @Model
  public final class Favorite {
    /// The preset the favorite is based on
    public var preset: Preset?
    /// The name of the favorite
    public var name: String?
    /// Optional notation for the favorite
    public var notes: String?
    /// Ordering among all favorites. New entities are add to the end of the existiing set.
    public var index: Int = -1
    /// Customization settings for the favorite
    @Relationship(deleteRule: .cascade) public var audioSettings: AudioSettings?

    public init(name: String, preset: Preset, index: Int) {
      self.name = name
      self.preset = preset
      self.index = index
    }
  }
}

public extension ModelContext {

  /**
   Create a new Favorite entity

   - parameter name: name to show
   - parameter preset: the Preset entity to use
   - returns: the new Favorite entity
   - throws if error creating new entity
   */
  func createFavorite(name: String, preset: Preset) throws -> Favorite {
    let nextIndex = (try? self.fetchCount(FetchDescriptor<Favorite>())) ?? 0
    let favorite = Favorite(name: name, preset: preset, index: nextIndex)
    insert(favorite)
    try save()
    return favorite
  }

  /**
   Obtain the collection of favorites, ordered by their index values.

   - returns: collection of Favorite entities
   - throws error if unable to fetch
   */
  func favorites() throws -> [Favorite] {
    try fetch(FetchDescriptor<Favorite>(sortBy: [SortDescriptor(\.index)]))
  }
}
