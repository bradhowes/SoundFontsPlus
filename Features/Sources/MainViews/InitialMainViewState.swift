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

    let activeSoundFont = modelContainer.mainContext.allSoundFonts()[0]
    self.activeSoundFont = activeSoundFont
    self.activePreset = activeSoundFont.orderedPresets[0]

    for soundFont in modelContainer.mainContext.allSoundFonts() {
      soundFont.visible = true
    }

    try? modelContainer.mainContext.save()
  }
}

