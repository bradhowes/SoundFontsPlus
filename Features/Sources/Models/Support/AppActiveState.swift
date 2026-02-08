// Copyright © 2025 Brad Howes. All rights reserved.

import Foundation

/**
 Holds active soundfont, preset, and tag IDs. The whole collection is accessed via a `Shared(.activeState)`
 */
public struct AppActiveState {

  public var activeSoundFontId: SoundFont.ID?
  public var activePresetId: Preset.ID?
  public var activeTagId: Tag.ID?

  public init(
    activeSoundFontId: SoundFont.ID? = nil,
    activePresetId: Preset.ID? = nil,
    activeTagId: Tag.ID? = nil
  ) {
    self.activeSoundFontId = activeSoundFontId
    self.activePresetId = activePresetId
    self.activeTagId = activeTagId
  }

  public static var `default`: Self {
    .init(
      activeSoundFontId: 1,
      activePresetId: 1,
      activeTagId: Tag.Ubiquitous.all.id
    )
  }

  public static var none: Self {
    .init()
  }
}

extension AppActiveState: Codable, Equatable, Sendable {}
