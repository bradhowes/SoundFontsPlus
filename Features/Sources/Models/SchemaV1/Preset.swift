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
    public var favorites: [FavoriteModel]?

    public init(soundFontPresetId: SoundFontPresetId, name: String, bank: Int, program: Int) {
      self.soundFontPresetId = soundFontPresetId
      self.displayName = name
      self.bank = bank
      self.program = program
      self.visible = true
      self.originalName = name
    }

    public static func fetchDescriptor(with predicate: Predicate<PresetModel>? = nil) -> FetchDescriptor<PresetModel> {
      .init(predicate: predicate, sortBy: [])
    }
  }
}

//public extension ModelContext {
//
//  /**
//   Obtain the collection of presets for a given SoundFont entity. The presets will be ordered by their `index` value.
//
//   - parameter soundFont: the SoundFont to query for
//   - returns: the array of Presets entities
//   */
//  func orderedPresets(for soundFont: SoundFont) -> [Preset] {
//    do {
//      return try fetch(Preset.fetchDescriptor(for: soundFont.persistentModelID))
//    } catch {
//      // fatalError("Failed to fetch presets: \(error)")
//    }
//    return []
//  }
//
//  /// TODO: remove when cascading is fixed
//
//  func delete(preset: Preset) {
//    if let faves = preset.favorites {
//      for favorite in faves {
//        delete(favorite)
//      }
//    }
//    delete(preset)
//  }
//}
//
//extension SchemaV1.Preset : Identifiable {
//  public var id: PersistentIdentifier { persistentModelID }
//}
//
//extension PersistenceReaderKey {
//  static public func presetKey(_ key: String) -> Self where Self == ModelIdentifierStorageKey<Preset.ID?> {
//    ModelIdentifierStorageKey(key)
//  }
//}
//
//extension PersistenceReaderKey where Self == ModelIdentifierStorageKey<Tag.ID?> {
//  static public var activePreset: Self { tagKey("activePreset") }
//}
