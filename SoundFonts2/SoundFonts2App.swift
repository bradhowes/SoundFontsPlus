//
//  SoundFonts2App.swift
//  SoundFonts2
//
//  Created by Brad Howes on 04/02/2024.
//

import SwiftUI
import SwiftData
import Models

@main
struct SoundFonts2App: App {
  var sharedModelContainer: ModelContainer = {
    do {
      return try ModelContainer(for: SoundFont.self)
    } catch {
      fatalError("Could not create ModelContainer: \(error)")
    }
  }()

  var body: some Scene {
    WindowGroup {
      ContentView()
    }
    .modelContainer(sharedModelContainer)
  }
}
