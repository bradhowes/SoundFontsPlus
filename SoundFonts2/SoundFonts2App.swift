// Copyright © 2024 Brad Howes. All rights reserved.

import ComposableArchitecture
import SwiftUI
import SwiftData

import Models
import MainViews

@main
struct SoundFonts2App: App {

  var body: some Scene {
    let initialState = makeInitialMainViewState()

    WindowGroup {
      MainView(activeSoundFont: initialState.activeSoundFont,
               activePreset: initialState.activePreset)
    }.modelContainer(initialState.modelContainer)
  }

  @MainActor
  func makeInitialMainViewState() -> InitialMainViewState {
#if DEBUG
    if CommandLine.arguments.contains("enable-testing") {
      return InitialMainViewState(isTemporary: true)
    }
#endif
    return InitialMainViewState(isTemporary: false)
  }

}
