import ComposableArchitecture
import SwiftUI
import SwiftData

import Models
import MainViews

@main
struct SoundFonts2App: App {

  var body: some Scene {
    let initialState = InitialState()
    WindowGroup {
      MainView(activeSoundFont: initialState.activeSoundFont,
               activePreset: initialState.activePreset)
    }.modelContainer(initialState.modelContainer)
  }
}
