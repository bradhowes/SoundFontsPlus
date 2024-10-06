// Copyright © 2024 Brad Howes. All rights reserved.

import Foundation
import SwiftData

extension SchemaV1 {

  @Model
  public final class PresetModel {
    public var name: String
    public var index: Int
    public var owner: SoundFontModel?
    public var bank: Int
    public var program: Int
    public var visible: Bool

    @Relationship(deleteRule: .cascade)
    public var info: PresetInfoModel?

    @Relationship(deleteRule: .cascade)
    public var audioSettings: AudioSettingsModel?

    @Relationship(deleteRule: .cascade, inverse: \FavoriteModel.preset)
    public var favorites: [FavoriteModel]?

    public init(owner: SoundFontModel, name: String, index: Int, bank: Int, program: Int) {
      self.name = name
      self.index = index
      self.owner = owner
      self.bank = bank
      self.program = program
      self.visible = true
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
