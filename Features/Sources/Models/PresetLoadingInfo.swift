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
  public let presetId: Preset.ID
  public let presetIndex: Int
  public let kind: SoundFont.Kind
  public let location: Data
  public let presetName: String
  public let originalSoundFontName: String
  public let soundFontName: String
  public let gain: Double
  public let pan: Double
}

extension PresetLoadingInfo {

  static func query(
    for originalSoundFontName: String,
    presetIndex: Int
  ) -> Select<Self.Columns.QueryValue, SoundFont, (Preset, AudioConfig?)> {
    SoundFont
      .where {
        // NOTE: this column should match the one that is used when creating the index on SoundFont to lookup by name.
        $0.originalName.eq(originalSoundFontName)
      }
      .join(Preset.all) {
        $1.index.eq(presetIndex) &&
        $0.id.eq($1.soundFontId)
      }
      .leftJoin(AudioConfig.all) {
        $1.id.eq($2.presetId)
      }
      .select {
        Columns(
          soundFontId: $0.id,
          presetId: $1.id,
          presetIndex: $1.index,
          kind: $0.kind,
          location: $0.location,
          presetName: $1.displayName,
          originalSoundFontName: $0.originalName,
          soundFontName: $0.displayName,
          gain: $2.gain ?? 0.0,
          pan: $2.pan ?? 0.0
        )
      }
  }

  /**
   Obtain the loading info for a given preset ID. Used when directing the app synth to begin using a preset.

   - parameter id: the preset to query for
   - returns: the optional `PresetLoadingInfo` for the preset
   */
  public static func `for`(id: Preset.ID) -> PresetLoadingInfo? {
    withDatabaseReader {
      try PresetLoadingInfo.query(for: id).fetchOne($0)
    } ?? nil
  }

  static func query(for id: Preset.ID) -> Select<Self.Columns.QueryValue, Preset, (SoundFont, AudioConfig?)> {
    Preset
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
          presetId: $0.id,
          presetIndex: $0.index,
          kind: $1.kind,
          location: $1.location,
          presetName: $0.displayName,
          originalSoundFontName: $1.originalName,
          soundFontName: $1.displayName,
          gain: $2.gain ?? 0.0,
          pan: $2.pan ?? 0.0
        )
      }
  }

  /**
   Obtain the loading info for a given sound font name and preset index. Used when directing the AUv3 synth to begin using the preset.

   - parameter soundFontName: the name of the sound font to query for
   - parameter presetIndex: the index of the preset to query for in the named sound font
   - returns: the optional `PresetLoadingInfo` for the preset
   */
  public static func `for`(soundFontName: String, presetIndex: Int) -> PresetLoadingInfo? {
    withDatabaseReader {
      try PresetLoadingInfo.query(for: soundFontName, presetIndex: presetIndex).fetchOne($0)
    } ?? nil
  }
}

extension PresetLoadingInfo: CustomStringConvertible {
  public var description: String {
    """
    <PresetLoadingInfo
      id=\(soundFontId)
      soundFontName="\(soundFontName)"
      presetIndex=\(presetIndex)
      kind="\(kind)"
      presetName="\(presetName)"
      originalSoundFontName="\(originalSoundFontName)"
      gain=\(gain)
      pan=\(pan)
    />
    """
  }
}

extension PresetLoadingInfo: Equatable, Sendable {}
