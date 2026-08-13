// Copyright © 2025 Brad Howes. All rights reserved.

import AVFAudio
import BaseSupport
import Dependencies
import DependenciesTestSupport
import Engine
import Foundation
import Models
import SQLiteData
import Tagged
import Testing
import TestSupport

@testable import SF2LibAU

@Suite(
  .dependencies {
    $0.audioGraph = .liveValue
    $0.audioSession = AudioSession.liveValue
    $0.defaultDatabase = TestSupport.testDatabase()
  },
  .serialized // due to SF2LibAU creation
)
@MainActor
struct SF2LibAUTests {

  func initialized(_ closure: (AVAudioUnitMIDIInstrument) async throws -> Void) async throws {
    @Dependency(\.audioGraph) var audioGraph
    @Dependency(\.audioSession) var audioSession
    let au: AVAudioUnitMIDIInstrument! = await SF2LibAU.create(register: true)
    #expect(au != nil)
    #expect(au.parameterTree != nil)

    #expect(audioSession.start() == true)
    #expect(audioGraph.start(audioGraph.engine, au) == true)

    try await closure(au)
  }

  @Test
  func creation() async throws {
    try await initialized { _ in }
  }

  @Test
  func sendMIDI() async throws {
    try await initialized { au in
      let presetInfo: PresetLoadingInfo! = PresetLoadingInfo.for(id: 1)
      #expect(presetInfo != nil)

      let location = try SoundFontKind(
        kind: presetInfo.kind,
        location: presetInfo.location,
        displayName: presetInfo.originalSoundFontName,
      )

      #expect(
        au.sendLoadFileUsePreset(
          path: location.url.path(percentEncoded: false),
          preset: presetInfo.presetIndex
        ) == true
      )

      au.startNote(60, withVelocity: 127, onChannel: 0)
    }
  }

  @Test
  func setFullState() async throws {
    try await initialized { au in
      let presetInfo: PresetLoadingInfo! = PresetLoadingInfo.for(id: 1)
      #expect(presetInfo != nil)

      let activeState: AUv3ActiveState = .init(
        soundFontName: presetInfo.originalSoundFontName,
        presetIndex: presetInfo.presetIndex,
        tagName: Tag.Ubiquitous.all.displayName ?? ""
      )

      let fullState = try FullState(activeState: activeState)
      au.auAudioUnit.fullState = fullState.state
    }
  }
}
