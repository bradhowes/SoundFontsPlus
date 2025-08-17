// Copyright © 2025 Brad Howes. All rights reserved.

import AVFAudio
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

      let delay = AVAudioUnitDelay()
      $0.delayDevice = .init(
        setConfig: { delay.setConfig($0) }
      )
      @Shared(.delayEffect) var delayEffect = delay

      let reverb = AVAudioUnitReverb()
      $0.reverbDevice = .init(
        setConfig: { reverb.setConfig($0) }
      )
      @Shared(.reverbEffect) var reverbEffect = reverb

      @Shared(.midiInputPortId) var midiInputPortId
      @Shared(.midi) var midi = .init(clientName: "SoundFonts+", uniqueId: Int32(midiInputPortId), midiProto: .legacy)
      midi?.start()
      @Shared(.midiMonitor) var midiMonitor = .init()
      midi?.receiver = midiMonitor
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
