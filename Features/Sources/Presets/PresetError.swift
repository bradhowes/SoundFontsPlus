// Copyright © 2025 Brad Howes. All rights reserved.

import Foundation
import Models

public enum PresetError: Error {
  case failedToSave(preset: Preset)
  case failedToFetch(presetId: Preset.ID, soundFontId: SoundFont.ID)
}
