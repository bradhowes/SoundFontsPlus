// Copyright © 2025 Brad Howes. All rights reserved.

import AudioToolbox.AudioComponent
import Foundation

private class BundleTag: NSObject {}

extension Bundle {

  @inlinable
  public func string(forKey key: String) -> String { infoDictionary?[key] as? String ?? "" }

  /// Obtain the release version number from the bundle info
  public var releaseVersionNumber: String { string(forKey: "CFBundleShortVersionString") }

  /// Obtain the build version number from the bundle info
  public var buildVersionNumber: String { string(forKey: "CFBundleVersion") }

  /// Obtain a version string from the bundle info
  public var versionString: String { "Version \(releaseVersionNumber).\(buildVersionNumber)" }

  public var changeLogFile: URL? { Bundle.main.url(forResource: "Changes", withExtension: "md", subdirectory: nil) }

  public var changeLog: String {
    guard let url = self.changeLogFile,
          let data = try? String(contentsOfFile: url.path, encoding: .utf8) else {
      return ""
    }
    return data
  }

  // Obtain the component description for the SF2LibAU app extension. This relies on the `main` bundle for values.
  public var audioComponentDescription: AudioComponentDescription {
    let componentType = FourCharCode(stringLiteral: self.string(forKey: "AU_COMPONENT_TYPE"))
    let componentSubtype = FourCharCode(stringLiteral: self.string(forKey: "AU_COMPONENT_SUBTYPE"))
    let componentManufacturer = FourCharCode(stringLiteral: self.string(forKey: "AU_COMPONENT_MANUFACTURER"))
    precondition(
      componentType != .invalidFourCharCode &&
      componentSubtype != .invalidFourCharCode &&
      componentManufacturer != .invalidFourCharCode
    )
    return .init(
      componentType: componentType,
      componentSubType: componentSubtype,
      componentManufacturer: componentManufacturer,
      componentFlags: 0,
      componentFlagsMask: 0
    )
  }
}
