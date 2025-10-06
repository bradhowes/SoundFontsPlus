// Copyright © 2025 Brad Howes. All rights reserved.

import Sharing

extension SharedKey where Self == AppStorageKey<KeyLabels>.Default {
  public static var keyLabels: Self { Self[.appStorage("keyLabels"), default: .cOnly] }
}

extension SharedKey where Self == AppStorageKey<Note>.Default {
  public static var firstVisibleKey: Self { Self[.appStorage("firstVisibleKey"), default: .C4] }
}
