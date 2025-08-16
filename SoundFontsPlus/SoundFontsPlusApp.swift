// Copyright © 2025 Brad Howes. All rights reserved.

import AudioUnit.AUParameters
// import BRHSplitView
import ComposableArchitecture
import MorkAndMIDI
import SwiftUI

@main
struct SoundFontsPlusApp: App {

  init() {
    prepareDependencies {
      // swiftlint:disable:next force_try
      $0.defaultDatabase = try! appDatabase()
      $0.defaultFileStorage = .fileSystem

      $0.delayDevice = .init(
        getConfig: { DelayConfig.Draft() },
        setConfig: { config in print(config) }
      )

      $0.reverbDevice = .init(
        getConfig: { ReverbConfig.Draft() },
        setConfig: { config in print(config) }
      )

      @Shared(.midiInputPortId) var midiInputPortId
      @Shared(.midi) var midi = MIDI(clientName: "SoundFonts+", uniqueId: Int32(midiInputPortId), midiProto: .legacy)
      @Shared(.midiMonitor) var midiMonitor
    }
  }

  var body: some Scene {
    WindowGroup {
      ContentView()
    }
  }
}

struct ContentView: View {
  var body: some View {
    ZStack {
      Color.black
        .ignoresSafeArea(edges: .all)

      AppFeatureView(store: Store(initialState: .init()) { AppFeature() })
        .environment(\.colorScheme, .dark)
        .defersSystemGestures(on: .bottom)
    }
  }
}
