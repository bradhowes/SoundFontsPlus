// Copyright © 2024 Brad Howes. All rights reserved.

import Foundation

public struct Location: Codable, Equatable {

  public enum Kind: String, Codable, CaseIterable {
    case builtin
    case installed
    case external
  }

  /// The kind of SF2 file
  public let kind: Kind
  /// Location of a builtin or installed SF2 file
  public let url: URL?
  /// Bookmark data for an external file that is outside of the sandbox documents directory. May point to a location
  /// that is currently not available, such as an external drive or an iCloud file that requires downloading.
  public let raw: Data?

  /// Full path to the file reference by the location. Currently, this is not supported for `external`
  /// locations.
  public var path: String {
    guard let url = self.url else { fatalError("Unexpected nil URL") }
    return url.path(percentEncoded: false)
  }
}
