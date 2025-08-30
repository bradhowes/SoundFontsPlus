import Foundation

private class BundleTag: NSObject {}

extension Bundle {

  @inlinable
  func string(forKey key: String) -> String { infoDictionary?[key] as? String ?? "" }

  /// Obtain the release version number from the bundle info
  public var releaseVersionNumber: String { string(forKey: "CFBundleShortVersionString") }

  /// Obtain the build version number from the bundle info
  public var buildVersionNumber: String { string(forKey: "CFBundleVersion") }

  /// Obtain a version string from the bundle info
  public var versionString: String { "Version \(releaseVersionNumber).\(buildVersionNumber)" }
}
