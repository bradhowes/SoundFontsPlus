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
    let schema = Schema([
      AudioSettingsModel.self,
      DelayConfigModel.self,
      FavoriteModel.self,
      PresetInfoModel.self,
      PresetModel.self,
      ReverbConfigModel.self,
      SoundFontModel.self,
      TagModel.self
    ])
    let modelConfiguration = ModelConfiguration(schema: schema, isStoredInMemoryOnly: true)

    do {
      return try ModelContainer(for: schema, configurations: [modelConfiguration])
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
