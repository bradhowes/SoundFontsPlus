// Copyright © 2024 Brad Howes. All rights reserved.

import Foundation
import SwiftData

@MainActor
public struct CRUD {

  let container: ModelContainer
  let context: ModelContext

  public init() throws {
    self.container = try ModelContainer(for: SoundFontModel.self, configurations: .init())
    self.context = container.mainContext
  }

  public func save() throws { try self.context.save() }

//  public func fetchSoundFonts(with tagId: TagModel.Id) throws -> [SoundFontModel] {
//    try self.context.fetch(FetchDescriptor<SoundFontModel>())
//  }
//
//  public func deleteFavorite(_ favorite: Favorite) {
//    let preset = favorite.soundFont.presets[favorite.index]
//    let index = preset.favorites.firstIndex(of: favorite)
//    favorite.soundFont.presets[favorite.index].favorites.remove(favorite)
//    self.context.delete(favorite.config)
//    self.context.delete(favorite)
//  }
//
//  public func deleteSoundFont(_ soundFont: SoundFont) {
//    soundFont.presets.forEach { preset in
//      preset.favorites.forEach { self.context.delete($0) }
//      self.context.delete($0)
//    }
//    self.context.delete(soundFont)
//  }
}

extension CRUD {
}
