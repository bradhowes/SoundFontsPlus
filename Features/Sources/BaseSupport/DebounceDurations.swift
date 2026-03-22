// Copyright © 2025 Brad Howes. All rights reserved.

import Dependencies
import DependenciesMacros
import Foundation

public struct DebounceDurations {
  public let effectsConfigurationSaves: Duration
  public let effectsDisplayUpdates: Duration

  public init(
    effectsConfigurationSaves: Duration,
    effectsDisplayUpdates: Duration,
  ) {
    self.effectsConfigurationSaves = effectsConfigurationSaves
    self.effectsDisplayUpdates = effectsDisplayUpdates
  }
}

extension DebounceDurations: Sendable, DependencyKey {
  public static var liveValue: DebounceDurations {
    .init(
      effectsConfigurationSaves: .milliseconds(1000),
      effectsDisplayUpdates: .milliseconds(100)
    )
  }

  public static var previewValue: DebounceDurations {
    .init(
      effectsConfigurationSaves: .milliseconds(1000),
      effectsDisplayUpdates: .milliseconds(100)
    )
  }

  public static var testValue: DebounceDurations {
    .init(
      effectsConfigurationSaves: .milliseconds(10),
      effectsDisplayUpdates: .milliseconds(1)
    )
  }
}

// extension DispatchQueue.SchedulerTimeType.Stride: @unchecked @retroactive Sendable {}
