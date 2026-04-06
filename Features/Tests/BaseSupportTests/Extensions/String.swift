// Copyright © 2025 Brad Howes. All rights reserved.

import DependenciesTestSupport
import Foundation
import Testing

@testable import BaseSupport

@Suite
struct StringTests {

  @Test
  func trimmed() {
    #expect("  Hello, World!  ".trimmed(or: "N/A") == "Hello, World!")
    #expect("    ".trimmed(or: "N/A") == "N/A")
    #expect("".trimmed(or: "N/A") == "N/A")
  }

  @Test
  func withoutExtension() {
    #expect("testing.foo.bar".withoutExtension == "testing.foo")
    #expect("testing".withoutExtension == "testing")
    #expect("".withoutExtension == "")
  }

  @Test
  func isAlphanumeric() {
    #expect("".isAlphanumeric() == false)
    #expect("a".isAlphanumeric())
    #expect("à".isAlphanumeric())
    #expect("a".isAlphanumeric(ignoreDiacritics: true))
    #expect("à".isAlphanumeric(ignoreDiacritics: true) == false)
    #expect("1".isAlphanumeric())
    #expect("a1".isAlphanumeric())
    #expect("a b".isAlphanumeric() == false)
    #expect("a*".isAlphanumeric() == false)
  }
}
