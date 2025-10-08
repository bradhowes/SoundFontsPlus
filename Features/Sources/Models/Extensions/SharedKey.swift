// Copyright © 2025 Brad Howes. All rights reserved.

import BaseSupport
import Foundation
import Sharing
import Tagged

extension SharedKey where Self == AppStorageKey<Bool>.Default {
  public static var favoritesOnTop: Self { Self[.appStorage("favoritesOnTop"), default: false] }
  public static var showOnlyFavorites: Self { Self[.appStorage("showOnlyFavorites"), default: false] }
  public static var sortPresetsByName: Self { Self[.appStorage("sortPresetsByName"), default: false] }
}

extension SharedKey where Self == FileStorageKey<ActiveState>.Default {
  public static var activeState: Self {
    Self[.fileStorage(.activeStateURL), default: .init()]
  }
}

// MARK: - InMemory settings

extension SharedKey where Self == InMemoryKey<SoundFont.ID?>.Default {
  public static var selectedSoundFontId: Self { Self[.inMemory("selectedSoundFont"), default: nil] }
}
