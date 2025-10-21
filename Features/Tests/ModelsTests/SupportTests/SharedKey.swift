// Copyright © 2025 Brad Howes. All rights reserved.

import ComposableArchitecture
import Sharing
import SnapshotTesting
import SwiftUI
import Testing

@testable import Models

@Suite
@MainActor
struct SharingTests {

  @Test func boolValues() {
    boolChecker(.favoritesOnTop)
    boolChecker(.showOnlyFavorites)
    boolChecker(.sortPresetsByName)
  }

  @Test func customValues() {
    @Shared(.selectedSoundFontId) var value3
    #expect(value3 == nil)
    $value3.withLock { $0 = 1 }
    #expect(value3 != nil)
  }

  func boolChecker(_ key: AppStorageKey<Bool>.Default) {
    @Shared(key) var value
    let initValue = value
    $value.withLock { $0.toggle() }
    #expect(value != initValue)
  }

  func doubleChecker(_ key: AppStorageKey<Double>.Default) {
    @Shared(key) var value
    let initValue = value
    $value.withLock { $0 += 1.0 }
    #expect(value != initValue)
  }

  func intChecker(_ key: AppStorageKey<Int>.Default) {
    @Shared(key) var value
    let initValue = value
    $value.withLock { $0 += 1 }
    #expect(value != initValue)
  }

  func stringChecker(_ key: AppStorageKey<String>.Default) {
    @Shared(key) var value
    let initValue = value
    $value.withLock { $0 += "testing" }
    #expect(value != initValue)
  }
}
