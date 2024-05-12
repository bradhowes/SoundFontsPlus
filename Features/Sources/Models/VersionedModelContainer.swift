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
    do {
      log.debug("make - creating container")
      let container = try ModelContainer(for: schema, configurations: [modelConfiguration])

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
      log.error("make - could not create ModelContainer - \(error)")
      fatalError("Could not create ModelContainer: \(error)")
    }
  }
}

public protocol ModelContextProvider : Actor {
  var context: ModelContext { get }
}

public extension ModelContextProvider {
  func insert<T: PersistentModel>(_ entity: T) {
    context.insert(entity)
  }
}

public actor BackgroundFontLoader : ModelContextProvider {
  public let executor: DefaultSerialModelExecutor
  public let context: ModelContext

  public init(container: ModelContainer) {
    let context = ModelContext(container)
    self.executor = .init(modelContext: context)
    self.context = context
  }

  public func load(url: URL) async throws {
    let location: Location = .init(kind: .builtin, url: url, raw: nil)
    let fileInfo = Engine.SF2FileInfo(url.path(percentEncoded: false))
    let soundFont = SoundFont(location: location, name: String(fileInfo.embeddedName()))
    let presets: [Preset] = (0..<fileInfo.size()).map { index in
      let presetInfo = fileInfo[index]
      let preset: Preset = .init(owner: soundFont, index: index, name: String(presetInfo.name()))
      return preset
    }
    soundFont.presets = presets
    context.insert(soundFont)
    try context.save()
  }
}

@MainActor
public class MainContext {
  public let context: ModelContext

  public init(container: ModelContainer) {
    self.context = container.mainContext
  }
}
//
//@MainActor
//class PreviewContainer {
//  static let previewContainer: ModelContainer = {
//    do {
//      let container = VersionedModelContainer.make(isTemporary: true)
//      let context = container.mainContext
//      for tag in SF2FileTag.allCases {
//        _ = try context.createSoundFont(resourceTag: tag)
//      }
//      return container
//    } catch {
//      fatalError("Failed to create model container for previewing: \(error.localizedDescription)")
//    }
//  }()
//}
