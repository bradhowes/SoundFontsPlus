// Copyright © 2025 Brad Howes. All rights reserved.

import Foundation
import OSLog

extension Logger {
  public static let subsystem = "com.braysoftware.SoundFonts"
  public static let models = Logger(subsystem: subsystem, category: "models")
  public static let presets = Logger(subsystem: subsystem, category: "presets")
  public static let soundFonts = Logger(subsystem: subsystem, category: "soundFonts")
  public static let tags = Logger(subsystem: subsystem, category: "tags")
}
