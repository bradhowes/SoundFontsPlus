// Copyright © 2025 Brad Howes. All rights reserved.

import Foundation
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
}

extension PresetLoadingInfo {

  static func query(for id: Preset.ID) -> Select<Self.Columns.QueryValue, Preset, (SoundFont, AudioConfig?)> {
    return Preset
      .where {
        $0.id.eq(id)
      }
      .join(SoundFont.all) {
        $0.soundFontId.eq($1.id)
      }
      .leftJoin(AudioConfig.all) {
        $0.id.eq($2.presetId)
      }
      .select {
        Columns(
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

  /**
   Obtain the loading info for a given preset ID. Used when directing the synth to begin using the preset.

   - parameter id: the preset to query for
   - returns: the optional `PresetLoadingInfo` for the preset
   */
  public static func `for`(id: Preset.ID) -> PresetLoadingInfo? {
    withDatabaseReader {
      try PresetLoadingInfo.query(for: id).fetchOne($0)
    } ?? nil
  }
}

extension PresetLoadingInfo: CustomStringConvertible {
  public var description: String {
    """
    <PresetLoadingInfo
      id=\(soundFontId)
      presetIndex=\(presetIndex)
      kind="\(kind)"
      presetName="\(presetName)"
      soundFontName="\(soundFontName)"
      gain=\(gain)
      pan=\(pan)
    />
    """
  }
}

extension PresetLoadingInfo: Equatable, Sendable {}
