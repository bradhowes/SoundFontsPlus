// Copyright © 2025 Brad Howes. All rights reserved.

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

  @Test
  func truncatedTail() async throws {
    let source = "This is a test of the emergency broadcasting system."
    #expect(source.truncated(to: 10) == "This is a…")
    #expect(source.truncated(to: 1) == "…")
    #expect(source.truncated(to: 99) == source)
  }

  @Test
  func truncatedWith() async throws {
    let source = "This is a test of the emergency broadcasting system."
    #expect(source.truncated(to: 10, with: "!") == "This is a!")
    #expect(source.truncated(to: 1, with: "!") == "!")
    #expect(source.truncated(to: 99, with: "!") == source)
  }

  @Test
  func truncatedAtPosition() async throws {
    let source = "This is a test of the emergency broadcasting system."
    #expect(source.truncated(to: 10, with: "!", at: .head) == "!g system.")
    #expect(source.truncated(to: 1, with: "!", at: .head) == "!")
    #expect(source.truncated(to: 99, with: "!", at: .head) == source)

    #expect(source.truncated(to: 10, with: "!", at: .middle) == "This !tem.")
    #expect(source.truncated(to: 1, with: "!", at: .middle) == "!")
    #expect(source.truncated(to: 99, with: "!", at: .middle) == source)
  }
}
