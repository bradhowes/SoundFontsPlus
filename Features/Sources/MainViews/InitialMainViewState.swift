// Copyright © 2024 Brad Howes. All rights reserved.

import Foundation
import SwiftData
import SwiftUI

import Models

@MainActor
public struct InitialMainViewState {

  public let modelContainer: ModelContainer
  public let activeSoundFont: SoundFont
  public let activePreset: Preset

  public init(isTemporary: Bool = false) {
    let modelContainer = VersionedModelContainer.make(isTemporary: isTemporary)
    self.modelContainer = modelContainer

    let tags = modelContainer.mainContext.tags()
    let activeSoundFont = modelContainer.mainContext.allSoundFonts()[0]
    self.activeSoundFont = activeSoundFont
    self.activePreset = activeSoundFont.orderedPresets[0]

#if DEBUG

    for soundFont in modelContainer.mainContext.allSoundFonts() {
      soundFont.visible = true
    }

    do {
      _ = try modelContainer.mainContext.tags()
      let old = modelContainer.mainContext.findTagByName(name: "User")
      old.forEach { modelContainer.mainContext.delete($0) }
      try modelContainer.mainContext.save()
    } catch {
      fatalError("Unable to update/save the models")
    }
    
#endif
  }
}

