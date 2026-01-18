// Copyright © 2025 Brad Howes. All rights reserved.

import Foundation

/**
 Holds active soundfont, preset, and tag IDs. The whole collection is accessed via a `Shared(.activeState)`
 */
public struct ActiveState {

  public var activeSoundFontId: SoundFont.ID?
  public var activePresetId: Preset.ID?
  public var activeTagId: Tag.ID?

  public var activeDelayConfigId: DelayConfig.ID?
  public var activeReverbConfigId: ReverbConfig.ID?

  public init(
    activeSoundFontId: SoundFont.ID?,
    activePresetId: Preset.ID?,
    activeTagId: Tag.ID?,
    activeDelayConfigId: DelayConfig.ID?,
    activeReverbConfigId: ReverbConfig.ID?
  ) {
    self.activeSoundFontId = activeSoundFontId
    self.activePresetId = activePresetId
    self.activeTagId = activeTagId
    self.activeDelayConfigId = activeDelayConfigId
    self.activeReverbConfigId = activeReverbConfigId
  }

  public static var `default`: Self {
    .init(
      activeSoundFontId: 1,
      activePresetId: 1,
      activeTagId: Tag.Ubiquitous.all.id,
      activeDelayConfigId: nil,
      activeReverbConfigId: nil
    )
  }

  public static var none: Self {
    .init(
      activeSoundFontId: nil,
      activePresetId: nil,
      activeTagId: nil,
      activeDelayConfigId: nil,
      activeReverbConfigId: nil
    )
  }
}

extension ActiveState: Codable, Equatable, Sendable {}
