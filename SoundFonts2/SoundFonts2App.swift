import ComposableArchitecture
import SwiftUI
import SwiftData

import Models
import MainViews

@main
struct SoundFonts2App: App {

  @MainActor
  static func makeInitialMainViewState() -> InitialMainViewState {
#if DEBUG
    if CommandLine.arguments.contains("enable-testing") {
      return InitialMainViewState(isTemporary: true)
    }
#endif
    return InitialMainViewState(isTemporary: false)
  }

  var body: some Scene {

    let initialState = Self.makeInitialMainViewState()

    WindowGroup {
      MainView(activeSoundFont: initialState.activeSoundFont,
               activePreset: initialState.activePreset)
    }.modelContainer(initialState.modelContainer)
  }
}
