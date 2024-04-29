// Copyright © 2024 Brad Howes. All rights reserved.

import Foundation
import SwiftData

import Engine
import SF2Files

public enum VersionedModelContainer {

  static func make(schema: Schema, isTemporary: Bool) throws -> ModelContainer {
    let modelConfiguration = ModelConfiguration(schema: schema, isStoredInMemoryOnly: isTemporary)
    return try ModelContainer(for: schema, configurations: [modelConfiguration])
  }

  static func make() throws -> ModelContainer {
    try make(schema: Schema.init(CurrentSchema.models, version: CurrentSchema.versionIdentifier),
             isTemporary: true)
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

@MainActor
class PreviewContainer {
  static let previewContainer: ModelContainer = {
    do {
      let container = try VersionedModelContainer.make()
      let context = container.mainContext
      for tag in SF2FileTag.allCases {
        _ = try context.createSoundFont(resourceTag: tag)
      }
      return container
    } catch {
      fatalError("Failed to create model container for previewing: \(error.localizedDescription)")
    }
  }()
}
