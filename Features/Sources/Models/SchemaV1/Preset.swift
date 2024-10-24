// Copyright © 2024 Brad Howes. All rights reserved.

import ComposableArchitecture
import Foundation
import SwiftData
import Tagged

extension SchemaV1 {

  @Model
  public final class PresetModel {
    public typealias Key = Tagged<PresetModel, Int>

    public var internalKey: Int
    public var key: Key { .init(internalKey) }

    public var displayName: String
    public var bank: Int
    public var program: Int
    public var visible: Bool

    public var originalName: String
    public var notes: String?

    public var owner: SoundFontModel?

    @Relationship(deleteRule: .cascade)
    public var audioSettings: AudioSettingsModel?

    @Relationship(deleteRule: .cascade)
    public var favorites: [FavoriteModel]

    public var orderedFavorites: [FavoriteModel] {
      return favorites.sorted(by: { $0.displayName < $1.displayName })
    }

    public init(owner: SoundFontModel, presetIndex: Int, name: String, bank: Int, program: Int) {
      self.owner = owner
      self.internalKey = presetIndex
      self.displayName = name
      self.bank = bank
      self.program = program
      self.visible = true
      self.originalName = name
      self.favorites = []
    }
  }
}

extension PersistenceReaderKey where Self == CodableAppStorageKey<PresetModel.Key> {
  public static var activePresetKey: Self {
    .init(.appStorage("activePresetKey"))
  }
}

extension PersistenceReaderKey where Self == PersistenceKeyDefault<CodableAppStorageKey<PresetModel.Key>> {
  public static var activePresetKey: Self { PersistenceKeyDefault(.activePresetKey, .init(-1)) }
}

