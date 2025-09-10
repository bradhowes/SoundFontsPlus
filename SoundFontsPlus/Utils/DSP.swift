import Foundation
import Numerics

public enum DSP {}

extension DSP {

  // Maximum absolute cents used for frequencies. This corresponds to 20kHz.
  static var maximumAbsoluteCents: Int { 13_508 }

  // Number of cents in octave
  static var centsPerOctave: Int { 1200 }

  // Attenuated samples at or below this value should be inaudible at 100 dB dynamic range.
  static var noiseFloor: Double { 0.00001 }
  static var noiseFloorCentiBels: Int { 960 }

  // Maximum attenuation defined in SF2 spec.
  static var maximumAttenuationCentiBels: Double { 1440.0 }

  // Lowest note frequency that we can generate This is C-1 in MIDI nomenclature or ~8.176 Hz
  static var lowestNoteFrequency: Double { 440.0 * Double.pow(2.0, -69 / 12) }

}

extension DSP {

  /**
   Convert centibels [0-1440] into an attenuation value from [1.0-0.0].

   - Zero indicates no attenuation (1.0)
   - 20 centibels (-2 dB) gives 0.1 attenuation (10% reduction of original signal)
   - 60 centibels (-6 dB) gives 0.5 attenuation (50% reduction of original signal)
   - 120 centibels (-12 dB) gives 0.25 attenuation

   and every 200 is a reduction by a power of 10 (200 = 0.1, 400 = 0.001, etc.)

   NOTE: attenuation greater than 96 dB is in the noise floor for 16-bit samples.

   - parameter value: value in centibels to convert
   - returns attenuation value
   */
  static func centibelsToAttenuation(value: Double) -> Double {
    guard value > 0 && value < maximumAttenuationCentiBels else { return 0.0 }
    return Double.pow(10.0, value / -200.0)
  }

  /**
   Convert a cents value in range[0-1200) into frequency

   */
  static func centsPartialLookup(value: Int) -> Double {
    6.875 * Double.pow(2.0, Double(value) / 1200.0)
  }

  static func panToCCValue(_ value: Double) -> UInt8 {
    // Map [-1 - 1.0] --> [0 - 127] in a linear transform
    UInt8((value + 1.0) / 2.0 * 127.0)
  }

  static func gainToCCValue(_ value: Double) -> UInt8 {
    // Map [0.0 - 1.0] -> [127 - 0] in a concave transform
    UInt8(negativeUnipolarConcave(value, minValue: 0.0, outputRange: 0...127))
  }

  static func negativeUnipolarConcave(_ value: Double, minValue: Double, outputRange: ClosedRange<Double>) -> Double {
    value == 1.0 ? 1.0 : -20.0 / 96.0 * Double.log10((((1.0 - value)*(1.0 - value)) / outputRange.distance))
  }
}
