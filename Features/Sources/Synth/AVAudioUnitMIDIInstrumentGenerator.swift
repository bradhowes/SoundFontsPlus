import AVFAudio
import Dependencies
import Foundation
import SF2LibAU

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

  public static func constant() async -> Self {
    let value = await SF2LibAU.create()
    return Self.constant(value)
  }

  /// Generate a value.
  public func generate() async -> AVAudioUnitMIDIInstrument? {
    await self.generator()
  }

  /**
   Initializes a generator that generates a value from a closure.

   - parameter generate: A closure that returns the current date when called.
   */
  public init(_ generator: @escaping @Sendable () async -> AVAudioUnitMIDIInstrument?) {
    self.generator = generator
  }
}

extension DependencyValues {

  public var avAudioUnitMIDIInstrumentGenerator: AVAudioUnitMIDIInstrumentGenerator {
    get { self[AVAudioUnitMIDIInstrumentGeneratorKey.self] }
    set { self[AVAudioUnitMIDIInstrumentGeneratorKey.self] = newValue }
  }

  private enum AVAudioUnitMIDIInstrumentGeneratorKey: DependencyKey {
    static let liveValue = AVAudioUnitMIDIInstrumentGenerator {
      await SF2LibAU.create()
    }
  }
}
