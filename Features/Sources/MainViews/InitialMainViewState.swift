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

    let activeSoundFont = modelContainer.mainContext.soundFonts()[0]
    self.activeSoundFont = activeSoundFont
    self.activePreset = activeSoundFont.orderedPresets[0]
  }
}

