import Foundation
import SwiftData
import SwiftUI

import Models

@MainActor
public struct InitialMainViewState {

  let modelContainer: ModelContainer
  let activeSoundFont: SoundFont
  let activePreset: Preset

  public init(isTemporary: Bool = false) {
    var isTemporary: Bool = isTemporary

#if DEBUG
    if CommandLine.arguments.contains("enable-testing") {
      isTemporary = true
    }
#endif

    let modelContainer = VersionedModelContainer.make(isTemporary: isTemporary)
    self.modelContainer = modelContainer

    let activeSoundFont = modelContainer.mainContext.soundFonts()[0]
    self.activeSoundFont = activeSoundFont
    self.activePreset = activeSoundFont.orderedPresets[0]
  }
}

