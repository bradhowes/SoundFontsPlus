// Copyright © 2025 Brad Howes. All rights reserved.

import Foundation
import Sharing
import SQLiteData
import Tagged

/**
 Attributes from Preset and SoundFont columns used to load the preset into the synth.
 */
@Selection
nonisolated public struct PresetLoadingInfo {
  public let soundFontId: SoundFont.ID
  public let presetIndex: Int
  public let kind: SoundFont.Kind
  public let location: Data
  public let presetName: String
  public let soundFontName: String
  public let gain: Double
  public let pan: Double

  static func query(for id: Preset.ID? = nil) -> Select<Self.Columns.QueryValue, Preset, (SoundFont, AudioConfig?)> {
    @Shared(.activeState) var activeState
    return Preset
      .where {
        $0.id.eq(id ?? activeState.activePresetId ?? -1)
      }
      .join(SoundFont.all) {
        $0.soundFontId.eq($1.id)
      }
      .leftJoin(AudioConfig.all) {
        $0.id.eq($2.presetId)
      }
      .select {
        PresetLoadingInfo.Columns(
          soundFontId: $1.id,
          presetIndex: $0.index,
          kind: $1.kind,
          location: $1.location,
          presetName: $0.displayName,
          soundFontName: $1.displayName,
          gain: $2.gain ?? 0.0,
          pan: $2.pan ?? 0.0
        )
      }
  }
}

extension PresetLoadingInfo: Equatable, Sendable {}
