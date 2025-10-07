// Copyright © 2025 Brad Howes. All rights reserved.

import AVFAudio
import ComposableArchitecture
import DelayEffect
import Dependencies
import Models
import MorkAndMIDI
import ReverbEffect
import Root
import Sharing
import SwiftUI

@main
struct SoundFontsPlusApp: App {

  init() {
    prepareDependencies {

      // swiftlint:disable:next force_try
      $0.defaultDatabase = try! appDatabase()
      $0.defaultFileStorage = .fileSystem
      $0.audioSession = .liveValue

      let delay = AVAudioUnitDelay()
      $0.delayDevice = .init(setConfig: { delay.setConfig($0) })
      @Shared(.delayEffect) var delayEffect = delay

      let reverb = AVAudioUnitReverb()
      $0.reverbDevice = .init( setConfig: { reverb.setConfig($0) })
      @Shared(.reverbEffect) var reverbEffect = reverb

      @Shared(.midiInputPortId) var midiInputPortId
      @Shared(.midi) var midi = .init(clientName: "SoundFonts+", uniqueId: Int32(midiInputPortId), midiProto: .legacy)
      midi?.start()
      @Shared(.midiMonitor) var midiMonitor = .init()
      midi?.receiver = midiMonitor

      @Shared(.confirmPresetHiding) var confirmPresetHiding
      $confirmPresetHiding.withLock { $0 = true }
    }
  }

  var body: some Scene {
    WindowGroup {
      if !isTesting {
        ContentView()
      }
    }
  }
}

struct ContentView: View {
  var body: some View {
    ZStack {
      Color.black
        .ignoresSafeArea(edges: .all)

      RootView(store: Store(initialState: .init()) { Root() })
        .environment(\.colorScheme, .dark)
      // We don't want to mistake keyboard activity for iOS app switching or other system gestures
        .defersSystemGestures(on: [.bottom, .leading, .trailing])
    }
  }
}
