// Copyright © 2024 Brad Howes. All rights reserved.

import Foundation
import SwiftData
import Models

public struct InitialModelContainerState {

  public let modelContainer: ModelContainer
  public let context: ModelContext
  public let activeSoundFont: SoundFont
  public let activePreset: Preset

  public init(isTemporary: Bool = false) {
    let container = VersionedModelContainer.make(isTemporary: isTemporary)
    self.modelContainer = container
    self.context = ModelContext(container)

    self.context.createAllUbiquitousTags()
    self.context.addBuiltInSoundFonts()

    let activeSoundFont = context.allSoundFonts()[0]
    self.activeSoundFont = activeSoundFont
    self.activePreset = activeSoundFont.orderedPresets[0]

#if DEBUG

//    for soundFont in modelContainer.mainContext.allSoundFonts() {
//      soundFont.visible = true
//    }
//
//    do {
//      _ = modelContainer.mainContext.tags()
//      let old = modelContainer.mainContext.findTagByName(name: "User")
//      old.forEach { modelContainer.mainContext.delete($0) }
//      try modelContainer.mainContext.save()
//    } catch {
//      fatalError("Unable to update/save the models")
//    }
    
#endif
  }
}
