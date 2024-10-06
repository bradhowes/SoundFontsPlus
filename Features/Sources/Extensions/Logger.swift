import Foundation
import OSLog


extension Logger {
  public static let subsystem = "com.braysoftware.SoundFonts2"
  public static let models = Logger(subsystem: subsystem, category: "models")
  public static let presetList = Logger(subsystem: subsystem, category: "presetList")
  public static let soundFontList = Logger(subsystem: subsystem, category: "soundFontList")
}


#if compiler(<6.0) || !hasFeature(InferSendableFromCaptures)
extension Logger: @unchecked @retroactive Sendable {}
#endif
