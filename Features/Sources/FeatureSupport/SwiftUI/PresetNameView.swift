// Copyright © 2025 Brad Howes. All rights reserved.

import Models
import Sharing
import SwiftUI

/**
 Custom view for a preset name.
 */
public struct PresetNameView: View {
  @Shared(.favoriteSymbolName) private var symbolName
  @Shared(.starFavoriteNames) private var starFavoriteNames
  private let preset: Preset?

  public init(preset: Preset?) {
    self.preset = preset
  }

  public var body: some View {
    HStack {
      if (preset?.isFavorite ?? false) && starFavoriteNames && !symbolName.isEmpty {
        Image(systemName: symbolName)
      }
      Text(preset?.displayName ?? "—")
        .font(.button)
    }
  }
}
