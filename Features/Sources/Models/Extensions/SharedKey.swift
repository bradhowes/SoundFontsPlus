// Copyright © 2025 Brad Howes. All rights reserved.

import BaseSupport
import Foundation
import Sharing
import Tagged

extension SharedKey where Self == AppStorageKey<Bool>.Default {
  public static var favoritesOnTop: Self { unsafe Self[.appStorage("favoritesOnTop", store: .group), default: false] }
  public static var hideEmptyTags: Self { unsafe Self[.appStorage("hideEmptyTags", store: .group), default: true] }
  public static var hideBuiltinFonts: Self { unsafe Self[.appStorage("hideBuiltinFonts", store: .group), default: false] }
  public static var showOnlyFavorites: Self { unsafe Self[.appStorage("showOnlyFavorites1", store: .group), default: false] }
  public static var sortPresetsByName: Self { unsafe Self[.appStorage("sortPresetsByName", store: .group), default: false] }
}

extension SharedKey where Self == AppStorageKey<Double>.Default {
  public static var sqlContentionTimeout: Self { Self[.appStorage("sqlContentionTimeout"), default: 15.0] }
}
