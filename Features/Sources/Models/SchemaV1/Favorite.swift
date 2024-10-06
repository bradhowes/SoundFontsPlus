// Copyright © 2024 Brad Howes. All rights reserved.

import AVFoundation
import Foundation
import SwiftData

extension SchemaV1 {

  @Model
  public final class FavoriteModel {
    /// The name of the favorite
    public var name: String?
    /// The preset the favorite is based on
    public var preset: PresetModel?
    /// Optional notation for the favorite
    public var notes: String?

    /// Customization settings for the favorite
    @Relationship(deleteRule: .cascade) public var audioSettings: AudioSettingsModel?

    public init(name: String, preset: PresetModel) {
      self.name = name
      self.preset = preset
    }
  }
}


//public extension ModelContext {
//
//  /**
//   Create a new Favorite entity
//
//   - parameter name: name to show
//   - parameter preset: the Preset entity to use
//   - returns: the new Favorite entity
//   - throws if error creating new entity
//   */
//  func createFavorite(name: String, preset: Preset) throws -> Favorite {
//    let nextIndex = (try? self.fetchCount(FetchDescriptor<Favorite>())) ?? 0
//    let favorite = Favorite(name: name, preset: preset, index: nextIndex)
//    insert(favorite)
//    try save()
//    return favorite
//  }
//
//  /**
//   Obtain the collection of favorites, ordered by their index values.
//
//   - returns: collection of Favorite entities
//   - throws error if unable to fetch
//   */
//  func favorites() throws -> [Favorite] {
//    try fetch(FetchDescriptor<Favorite>(sortBy: [SortDescriptor(\.index)]))
//  }
//}
