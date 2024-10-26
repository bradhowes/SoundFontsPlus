// Copyright © 2024 Brad Howes. All rights reserved.

import AVFoundation
import Dependencies
import Foundation
import SwiftData

extension SchemaV1 {

  @Model
  public final class FavoriteModel {
    public var displayName: String

    /// Optional notation for the favorite
    public var notes: String?

    @Relationship(deleteRule: .cascade)
    public var audioSettings: AudioSettingsModel?

    public var basis: PresetModel

    public init(preset: PresetModel, displayName: String) {
      self.basis = preset
      self.displayName = displayName
    }

    public static func fetchDescriptor(predicate: Predicate<FavoriteModel>? = nil) -> FetchDescriptor<FavoriteModel> {
      .init(predicate: predicate, sortBy: [SortDescriptor(\.displayName)])
    }
  }
}

extension SchemaV1.FavoriteModel {

  /**
   Create a new Favorite entity

   - parameter name: name to show
   - parameter preset: the Preset entity to use
   - returns: the new Favorite entity
   - throws if error creating new entity
   */
  public static func create(preset: PresetModel) throws -> FavoriteModel {
    @Dependency(\.modelContextProvider) var context

    let newName = preset.displayName + " - \(preset.favorites.count + 1)"
    let favorite = FavoriteModel(
      preset: preset,
      displayName: newName
    )

    context.insert(favorite)

    if let audioSettings = preset.audioSettings {
      let dupe = try audioSettings.duplicate()
      context.insert(dupe)
      favorite.audioSettings = dupe
    }

    preset.favorites.append(favorite)

    try context.save()

    return favorite
  }

  public func delete() throws {
    @Dependency(\.modelContextProvider) var context
    basis.favorites.remove(at: basis.favorites.firstIndex(of: self)!)
    context.delete(self)
    try context.save()
  }
}
