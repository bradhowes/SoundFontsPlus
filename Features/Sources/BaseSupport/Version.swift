// Copyright © 2025 Brad Howes. All rights reserved.

import Foundation

public struct Version: Comparable {

  public let major: Int
  public let minor: Int
  public let patch: Int

  public init(_ major: Int, _ minor: Int, _ patch: Int) {
    self.major = major
    self.minor = minor
    self.patch = patch
  }

  static func parse(_ value: String) -> Self? {
    let parts = value.split(separator: ".", omittingEmptySubsequences: false)
    guard parts.count == 3 else { return nil }
    let ints = parts.compactMap { Int($0) }.filter { $0 >= 0 }
    guard ints.count == 3 else { return nil }
    return .init(ints[0], ints[1], ints[2])
  }

  public static func < (lhs: Version, rhs: Version) -> Bool {
    lhs.major < rhs.major || (lhs.major == rhs.major && (lhs.minor < rhs.minor || (lhs.minor == rhs.minor && lhs.patch < rhs.patch)))
  }

  public static func == (lhs: Version, rhs: Version) -> Bool {
    lhs.major == rhs.major && lhs.minor == rhs.minor && lhs.patch == rhs.patch
  }
}
