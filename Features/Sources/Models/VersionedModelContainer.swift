// Copyright © 2024 Brad Howes. All rights reserved.

import OSLog
import Foundation
import SwiftData

import Engine
import SF2ResourceFiles


extension FetchDescriptor {
  init(fetchLimit: Int) {
    self.init()
    self.fetchLimit = fetchLimit
  }
}

public enum VersionedModelContainer {
  
  @MainActor
  static let log = Logger(subsystem: "com.braysoftware.SoundFonts2.Models", category: "VersionedModelContainer")

  @MainActor
  public static func make(isTemporary: Bool) -> ModelContainer {
    log.debug("make - isTemporary: \(isTemporary)")
    let schema = Schema.init(CurrentSchema.models, version: CurrentSchema.versionIdentifier)
    let modelConfiguration = ModelConfiguration(schema: schema, isStoredInMemoryOnly: isTemporary)

    log.debug("groupAppContainer: \(modelConfiguration.groupAppContainerIdentifier ?? "N/A", privacy: .public)")
    log.debug("groupAppContainer: \(modelConfiguration.url, privacy: .public)")
    log.debug("sharedDocumentsDirectory: \(FileManager.default.sharedDocumentsDirectory, privacy: .public)")

    do {
      log.debug("make - creating container")
      let container = try ModelContainer(for: schema, configurations: [modelConfiguration])

      // container.mainContext.container.deleteAllData()

      log.debug("make - creating tags if necessary")
      let _ = container.mainContext.tags()

      log.debug("make - checking for non-empty SoundFont collection")
      let detectEmptyFetchDescriptor = FetchDescriptor<SoundFont>(fetchLimit: 1)
      guard try container.mainContext.fetch(detectEmptyFetchDescriptor).isEmpty else {
        log.debug("make - not empty")
        return container
      }

      log.debug("make - installing built-in SF2 files")
      try container.mainContext.addBuiltInSoundFonts()
      return container
    } catch {
      log.error("make - could not create ModelContainer - \(error, privacy: .public)")
      fatalError("Could not create ModelContainer: \(error)")
    }
  }
}
