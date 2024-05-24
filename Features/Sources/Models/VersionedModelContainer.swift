// Copyright © 2024 Brad Howes. All rights reserved.

import OSLog
import Foundation
import SwiftData
import SwiftUI
import Dependencies
import DependenciesMacros
import XCTestDynamicOverlay

import Engine
import Extensions
import SF2ResourceFiles


extension FetchDescriptor {
  init(fetchLimit: Int) {
    self.init()
    self.fetchLimit = fetchLimit
  }
}

public enum VersionedModelContainer {
  
  static let log = Logger.models

  public static func make(isTemporary: Bool) -> ModelContainer {
    log.debug("make - isTemporary: \(isTemporary)")
    let schema = Schema.init(CurrentSchema.models, version: CurrentSchema.versionIdentifier)
    let modelConfiguration = ModelConfiguration(schema: schema, isStoredInMemoryOnly: isTemporary)

    log.debug("groupAppContainer: \(modelConfiguration.groupAppContainerIdentifier ?? "N/A", privacy: .public)")
    log.debug("groupAppContainer: \(modelConfiguration.url, privacy: .public)")
    log.debug("sharedDocumentsDirectory: \(FileManager.default.sharedDocumentsDirectory, privacy: .public)")

    do {
      log.debug("make - creating container")
      return try ModelContainer(for: schema, configurations: [modelConfiguration])
    } catch {
      log.error("make - could not create ModelContainer - \(error, privacy: .public)")
      fatalError("Could not create ModelContainer: \(error)")
    }
  }
}

@DependencyClient
public struct ModelContextProvider: Sendable {

  public var generate: @Sendable () throws -> ModelContext

  public init(provider: @Sendable @escaping () -> ModelContext) {
    self.generate = provider
  }
}

extension ModelContextProvider: DependencyKey {

  public static func make(isTemporary: Bool) -> Self {
    // Create a new container and use it for future context creations
    let container = VersionedModelContainer.make(isTemporary: isTemporary)
    return Self { ModelContext(container) }
  }

  /// Create factory to use for live data (one-time container creation)
  public static let liveValue: ModelContextProvider = make(isTemporary: false)

  /// Create factory to use for tests data (many container creations, not shared)
  public static var testValue: ModelContextProvider { make(isTemporary: true) }
}

extension DependencyValues {
  public var modelContextProvider: ModelContextProvider {
    get { self[ModelContextProvider.self] }
    set { self[ModelContextProvider.self] = newValue }
  }
}
