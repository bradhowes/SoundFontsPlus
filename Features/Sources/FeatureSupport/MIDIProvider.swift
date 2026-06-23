// Copyright © 2025 Brad Howes. All rights reserved.

import AVFAudio.AVAudioSession
import Dependencies
import MorkAndMIDI
import Sharing

/**
 Dependency that optionally creates a new MIDI endpoint if `isAUv3` returns `true`. This is the case when running as an application
 but not when running as an AUv3 component.
 */
public struct MIDIProvider: Sendable {
  public let midi: @Sendable () -> MIDI?

  public init(midiProvider: @Sendable @escaping () -> MIDI?) {
    self.midi = midiProvider
  }

  public static func makeMIDI(clientName: String, midiProto: MIDIProto = .v1_0) -> MIDI {
    @Shared(.midiInputPortId) var midiInputPortId
    let midi = MIDI(clientName: clientName, uniqueId: Int32(midiInputPortId), midiProto: midiProto)
    DispatchQueue.main.async { midi.start() }
    return midi
  }
}

extension MIDIProvider: DependencyKey {
  public static var liveValue: MIDIProvider {
    @Shared(.isAUv3) var isAUv3
    let midi: MIDI? = isAUv3 ? nil : makeMIDI(clientName: "SoundFontsPlus")
    return .init(midiProvider: { midi })
  }
}

extension MIDIProvider: TestDependencyKey {
  public static var testValue: MIDIProvider {
    .init(midiProvider: { nil })
  }
}

extension DependencyValues {
  public var midiProvider: MIDIProvider {
    get { self[MIDIProvider.self] }
    set { self[MIDIProvider.self] = newValue }
  }
}
