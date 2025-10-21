// Copyright © 2025 Brad Howes. All rights reserved.

import Foundation
import Testing

@testable import BaseSupport

@Suite
struct FourCharCodeTests {

  @Test func isPrintableAscii() {
    #expect(!Character(UnicodeScalar(31)).isPrintableASCII)
    #expect(Character(" ").isPrintableASCII)
    #expect(Character(UnicodeScalar(126)).isPrintableASCII)
    #expect(!Character(UnicodeScalar(127)).isPrintableASCII)
    #expect(!Character("ñ").isPrintableASCII)
  }

  @Test func initial() {
    #expect(FourCharCode("1234") == 825373492)
    #expect(FourCharCode(String("1234")) == 825373492)
    #expect(FourCharCode("") == FourCharCode.invalidFourCharCode)
    #expect(FourCharCode("1") == FourCharCode.invalidFourCharCode)
    #expect(FourCharCode("12") == FourCharCode.invalidFourCharCode)
    #expect(FourCharCode("123") == FourCharCode.invalidFourCharCode)
    #expect(FourCharCode("niño") == FourCharCode.invalidFourCharCode)
  }

  @Test func stringValue() {
    #expect(FourCharCode("1234").stringValue == "1234")
    #expect(FourCharCode.invalidFourCharCode.stringValue == "????")
  }
}
