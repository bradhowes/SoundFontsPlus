//
//  SoundFonts2App.swift
//  SoundFonts2
//
//  Created by Brad Howes on 04/02/2024.
//

import SwiftUI
import SwiftData
import Models
import MainViews

@main
struct SoundFonts2App: App {

  var body: some Scene {
    WindowGroup {
      MainView()
    }.modelContainer(VersionedModelContainer.make(isTemporary: false))
  }
}
