// Copyright © 2025 Brad Howes. All rights reserved.

import Foundation
import Tagged

public struct ActiveState: Codable, Equatable, Sendable {

  public var activeSoundFontId: SoundFont.ID?
  public var activePresetId: Preset.ID?
  public var activeTagId: FontTag.ID?

  public var activeDelayConfigId: DelayConfig.ID?
  public var activeReverbConfigId: ReverbConfig.ID?

  public init() {
    activeSoundFontId = SoundFont.ID(rawValue: 1)
    activePresetId = Preset.ID(rawValue: 1)
    activeTagId = FontTag.Ubiquitous.all.id
    activeDelayConfigId = nil
    activeReverbConfigId = nil
  }
}
