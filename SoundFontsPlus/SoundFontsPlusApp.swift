// Copyright © 2025 Brad Howes. All rights reserved.

import AppRoot
import AVFAudio
import ComposableArchitecture
import DelayEffect
import Dependencies
import FeatureSupport
import Models
import MorkAndMIDI
import ReverbEffect
import Sharing
import SwiftUI

@main
struct SoundFontsPlusApp: App {

  init() {
    prepareDependencies {
      @Shared(.isAUv3) var isAUv3 = false

      $0.audioGraph = .liveValue
      $0.audioSession = .liveValue

      // swiftlint:disable:next force_try
      $0.defaultDatabase = try! appDatabase()
      $0.defaultFileStorage = .fileSystem

      $0.synthAUv3ComponentDescription = SynthAUv3ComponentDescription.liveValue

      let delay = AVAudioUnitDelay()
      $0.delayDevice = .init(setConfig: { delay.setConfig($0) })
      @Shared(.delayEffect) var delayEffect = delay

      let reverb = AVAudioUnitReverb()
      $0.reverbDevice = .init( setConfig: { reverb.setConfig($0) })
      @Shared(.reverbEffect) var reverbEffect = reverb

      let engine = AVAudioEngine()
      @Shared(.audioEngine) var audioEngine = engine

      @Shared(.midiInputPortId) var midiInputPortId
      @Shared(.midi) var midi = .init(clientName: "SoundFonts+", uniqueId: Int32(midiInputPortId), midiProto: .legacy)
      midi?.start()
      @Shared(.midiMonitor) var midiMonitor = .init()
      midi?.receiver = midiMonitor

//      @Shared(.confirmPresetHiding) var confirmPresetHiding
//      $confirmPresetHiding.withLock { $0 = true }
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

      AppRootView(store: Store(initialState: .init()) { AppRoot() })
        .environment(\.colorScheme, .dark)
      // We don't want to mistake keyboard activity for iOS app switching or other system gestures
        .defersSystemGestures(on: [.bottom, .leading, .trailing])
    }
  }
}
