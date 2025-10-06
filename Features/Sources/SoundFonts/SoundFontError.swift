// Copyright © 2025 Brad Howes. All rights reserved.

import Foundation
import Models

public enum SoundFontError: Error {
  case failedToSave(preset: Preset)
  case failedToFetch(soundFontId: SoundFont.ID)
}
