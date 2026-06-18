// Copyright © 2025 Brad Howes. All rights reserved.

import Dependencies
import DependenciesTestSupport
import Testing

@testable import BaseSupport

struct DebounceDurationsTests {

  @Test(
    .dependencies {
      $0.debounceDurations = .liveValue
    }
  )
  func liveValues() async throws {
    @Dependency(\.debounceDurations) var dd
    #expect(dd.effectsConfigurationSaves == .milliseconds(1000))
    #expect(dd.effectsDisplayUpdates == .milliseconds(100))
  }

  @Test(
    .dependencies {
      $0.debounceDurations = .previewValue
    }
  )
  func previewValues() async throws {
    @Dependency(\.debounceDurations) var dd
    #expect(dd.effectsConfigurationSaves == .milliseconds(100))
    #expect(dd.effectsDisplayUpdates == .milliseconds(10))
  }

  @Test(
    .dependencies {
      $0.debounceDurations = .testValue
    }
  )
  func testValues() async throws {
    @Dependency(\.debounceDurations) var dd
    #expect(dd.effectsConfigurationSaves == .milliseconds(10))
    #expect(dd.effectsDisplayUpdates == .milliseconds(1))
  }
}
