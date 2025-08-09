// Copyright © 2025 Brad Howes. All rights reserved.

import Foundation
import SharingGRDB
import Tagged

/**
 Attributes from Preset and SoundFont columns used to load the preset
 */
@Selection
public struct PresetLoadingInfo: Equatable, Sendable {
  public let soundFontId: SoundFont.ID
  public let presetIndex: Int
  public let kind: SoundFont.Kind
  public let location: Data
  public let presetName: String
  public let soundFontName: String

  public init(
    soundFontId: SoundFont.ID,
    presetIndex: Int,
    kind: SoundFont.Kind,
    location: Data,
    presetName: String,
    soundFontName: String
  ) {
    self.soundFontId = soundFontId
    self.presetIndex = presetIndex
    self.kind = kind
    self.location = location
    self.presetName = presetName
    self.soundFontName = soundFontName
  }

  static var query: Select<PresetLoadingInfo.Columns.QueryValue, SoundFont, Preset> {
    @Shared(.activeState) var activeState
    return SoundFont
      .join(Preset.all) {
        $1.soundFontId.eq($0.id)
      }
      .select {
        PresetLoadingInfo.Columns(
          soundFontId: $0.id,
          presetIndex: $1.index,
          kind: $0.kind,
          location: $0.location,
          presetName: $1.displayName,
          soundFontName: $0.displayName
        )
      }
      .where {
        $1.id.eq(activeState.activePresetId ?? -1)
      }
  }
}
