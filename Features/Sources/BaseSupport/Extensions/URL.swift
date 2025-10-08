import Foundation

extension URL {
  static public var activeStateURL: URL { URL.applicationSupportDirectory.appendingPathComponent("activeState.json")
  }
}
