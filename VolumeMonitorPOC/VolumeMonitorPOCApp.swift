import BaseSupport
import ComposableArchitecture
import Dependencies
import SwiftUI
import VolumeMonitor

@main
struct VolumeMonitorPOCApp: App {

  init() {
    prepareDependencies {
      $0.audioSession = .liveValue
      $0.defaultFileStorage = .fileSystem
    }
  }

  var body: some Scene {
    WindowGroup {
      ContentView(store: .init(initialState: VolumeMonitor.State()) {
        VolumeMonitor()
      })
    }
  }
}
