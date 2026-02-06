// Copyright © 2025 Brad Howes. All rights reserved.

import BaseSupport
import Foundation
import Sharing
import Tagged

extension SharedKey where Self == AppStorageKey<Bool>.Default {
  public static var favoritesOnTop: Self { Self[.appStorage("favoritesOnTop"), default: false] }
  public static var hideEmptyTags: Self { Self[.appStorage("hideEmptyTags"), default: true] }
  public static var hideBuiltinFonts: Self { Self[.appStorage("hideBuiltinFonts"), default: false] }
  public static var showOnlyFavorites: Self { Self[.appStorage("showOnlyFavorites"), default: false] }
  public static var sortPresetsByName: Self { Self[.appStorage("sortPresetsByName"), default: false] }
}

extension SharedKey where Self == AppStorageKey<Double>.Default {
  public static var sqlContentionTimeout: Self { Self[.appStorage("sqlContentionTimeout"), default: 15.0] }
}

extension SharedKey where Self == FileStorageKey<ActiveState>.Default {
  public static var activeState: Self {
    @Shared(.activeStateURL) var activeStateURL
    // swiftlint:disable:next force_unwrapping
    return Self[.fileStorage(activeStateURL!), default: .default]
  }
}

extension SharedKey where Self == InMemoryKey<SoundFont.ID?>.Default {
  public static var selectedSoundFontId: Self { Self[.inMemory("selectedSoundFont"), default: nil] }
}

extension SharedKey where Self == InMemoryKey<URL?>.Default {
  public static var activeStateURL: Self { Self[.inMemory("activeStateURL"), default: nil] }
}
