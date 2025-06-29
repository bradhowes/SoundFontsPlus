import Sharing
import SwiftUI

/**
 Custom view for a preset name.
 */
public struct PresetNameView: View {
  @Shared(.favoriteSymbolName) var symbolName
  @Shared(.starFavoriteNames) var starFavoriteNames
  private let preset: Preset?

  public init(preset: Preset?) {
    self.preset = preset
  }

  public var body: some View {
    HStack {
      if (preset?.isFavorite ?? false) && starFavoriteNames {
        Image(systemName: symbolName)
      }
      Text(preset?.displayName ?? "—")
    }
  }
}
