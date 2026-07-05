import AVFAudio
import Dependencies
import Foundation

public struct AVAudioUnitMIDIInstrumentGenerator: Sendable {
  private var generator: @Sendable () async -> AVAudioUnitMIDIInstrument?

  /**
   A generator that returns the same audio unit.

   - parameter instrument: the audio unit to return.
   - returns: A generator that always returns the same value.
   */
  public static func constant(_ instrument: AVAudioUnitMIDIInstrument?) -> Self {
    Self { instrument }
  }

  /**
   A generator that returns the same SF2LibAU instance.

   - returns: A generator that always returns the same value.
   */
  public static func constant() async -> Self {
    let value = await SF2LibAU.create(register: true)
    return Self.constant(value)
  }

  /// Generate a value.
  public func generate() async -> AVAudioUnitMIDIInstrument? {
    await self.generator()
  }

  /**
   Initializes a generator that generates a value from a closure.

   - parameter generator: A closure that returns the current date when called.
   */
  public init(_ generator: @escaping @Sendable () async -> AVAudioUnitMIDIInstrument?) {
    self.generator = generator
  }
}

extension AVAudioUnitMIDIInstrumentGenerator: DependencyKey {

  public static var liveValue: Self {
    .init {
      await SF2LibAU.create(register: true)
    }
  }

  public static var previewValue: Self {
    .init {
      await SF2LibAU.create(register: true)
    }
  }

  public static var testValue: Self {
    .init {
      unimplemented("generate", placeholder: nil)
    }
  }
}

extension DependencyValues {

  public var avAudioUnitMIDIInstrumentGenerator: AVAudioUnitMIDIInstrumentGenerator {
    get { self[AVAudioUnitMIDIInstrumentGenerator.self] }
    set { self[AVAudioUnitMIDIInstrumentGenerator.self] = newValue }
  }
}
