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

  @MainActor
  static let modelContainer: ModelContainer = {
    do {
      let container = try ModelContainer(for: SoundFont.self)
      var itemsFetchDescriptor = FetchDescriptor<SoundFont>()
      itemsFetchDescriptor.fetchLimit = 1

      guard try container.mainContext.fetch(itemsFetchDescriptor).isEmpty else {
        return container
      }

      try container.mainContext.createBuiltInSoundFonts()

      return container

    } catch {
      fatalError("Could not create ModelContainer: \(error)")
    }
  }()

  var body: some Scene {
    WindowGroup {
      ContentView()
    }.modelContainer(VersionedModelContainer.make(isTemporary: true))
  }
}
