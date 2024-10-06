// Copyright © 2024 Brad Howes. All rights reserved.

import AVFoundation
import Dependencies
import Foundation
import SwiftData

extension SchemaV1 {

  @Model
  public final class FavoriteModel {
    public var soundFontPresetId: SoundFontPresetId
    public var displayName: String

    /// Optional notation for the favorite
    public var notes: String?

    @Relationship(deleteRule: .cascade)
    public var audioSettings: AudioSettingsModel?

    public init(soundFontPresetId: SoundFontPresetId, displayName: String) {
      self.soundFontPresetId = soundFontPresetId
      self.displayName = displayName
    }

    static func fetchDescriptor(predicate: Predicate<FavoriteModel>? = nil) -> FetchDescriptor<FavoriteModel> {
      .init(predicate: predicate, sortBy: [SortDescriptor(\.displayName)])
    }
  }
}

public extension SchemaV1.FavoriteModel {

  /**
   Create a new Favorite entity

   - parameter name: name to show
   - parameter preset: the Preset entity to use
   - returns: the new Favorite entity
   - throws if error creating new entity
   */
  func create(preset: PresetModel) throws -> FavoriteModel {
    @Dependency(\.modelContextProvider) var context

    let favorite = FavoriteModel(
      soundFontPresetId: preset.soundFontPresetId,
      displayName: preset.displayName
    )

    context.insert(favorite)

    if let audioSettings = preset.audioSettings {
      let dupe = audioSettings.duplicate()
      context.insert(dupe)
      favorite.audioSettings = dupe
    }

    try context.save()

    return favorite
  }
}
