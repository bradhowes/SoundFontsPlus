// Copyright © 2025 Brad Howes. All rights reserved.

import Sharing

// MARK: - AppStorage Bool settings

extension SharedKey where Self == AppStorageKey<Bool>.Default {
  public static var copyFileWhenInstalling: Self { Self[.appStorage("copyFileWhenInstalling"), default: true]}
}
