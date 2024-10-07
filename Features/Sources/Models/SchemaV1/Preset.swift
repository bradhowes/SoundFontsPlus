// Copyright © 2024 Brad Howes. All rights reserved.

import Foundation
import SwiftData

extension SchemaV1 {

  @Model
  public final class PresetModel {
    public var soundFontPresetId: SoundFontPresetId
    public var displayName: String
    public var bank: Int
    public var program: Int
    public var visible: Bool

    public var originalName: String
    public var notes: String?

    @Relationship(deleteRule: .cascade)
    public var audioSettings: AudioSettingsModel?

    @Relationship(deleteRule: .cascade)
    public var favorites: [FavoriteModel]

    public var orderedFavorites: [FavoriteModel] {
      return favorites.sorted(by: { $0.displayName < $1.displayName })
    }

    public init(soundFontPresetId: SoundFontPresetId, name: String, bank: Int, program: Int) {
      self.soundFontPresetId = soundFontPresetId
      self.displayName = name
      self.bank = bank
      self.program = program
      self.visible = true
      self.originalName = name
      self.favorites = []
    }

    public static func fetchDescriptor(with predicate: Predicate<PresetModel>? = nil) -> FetchDescriptor<PresetModel> {
      .init(predicate: predicate, sortBy: [SortDescriptor(\.soundFontPresetId.preset)])
    }
  }
}
