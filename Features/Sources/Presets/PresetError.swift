// Copyright © 2025 Brad Howes. All rights reserved.

import FeatureSupport

public enum PresetError: Error {
  case failedToSave(preset: Preset)
  case failedToFetch(presetId: Preset.ID, soundFontId: SoundFont.ID)
}
