// Copyright © 2025 Brad Howes. All rights reserved.

import Testing
import Numerics

@testable import BaseSupport

@Suite
struct DSPTests {

  @Test func panToCCValue() throws {
    #expect(DSP.panToCCValue(-1.0) == UInt8(0))
    #expect(DSP.panToCCValue(0.0) == UInt8(63))
    #expect(DSP.panToCCValue(1.0) == UInt8(127))
  }

  @Test func gainToCCValue() throws {
    #expect(DSP.gainToCCValue(1.0) == UInt8(1))
    #expect(DSP.gainToCCValue(0.0) == UInt8(0))
  }

  @Test func attenuationConversions() throws {
    var gain = DSP.Attenuation(value: 0.0)
    #expect(gain.slider.isApproximatelyEqual(to: 0.0))
    #expect(gain.value.isApproximatelyEqual(to: 0.0))
    gain.update(1.0)
    #expect(gain.slider == 1.0)
    #expect(gain.value == 1.0)
    gain.update(0.5)
    #expect(gain.slider.isApproximatelyEqual(to: 0.5))
    #expect(gain.value.isApproximatelyEqual(to: 0.8745708351400079))
    gain.update(0.25)
    #expect(gain.slider.isApproximatelyEqual(to: 0.25))
    #expect(gain.value.isApproximatelyEqual(to: 0.7491416702800157))
    gain.update(0.10)
    #expect(gain.slider.isApproximatelyEqual(to: 0.10))
    #expect(gain.value.isApproximatelyEqual(to: 0.5833333333333333))
    gain.update(0.0)
    #expect(gain.slider.isApproximatelyEqual(to: 0.0))
    #expect(gain.value.isApproximatelyEqual(to: 0.0))
  }

  @Test func panConversions() throws {
    var pan = DSP.Pan(value: 0.0)
    #expect(pan.slider.isApproximatelyEqual(to: 0.0))
    #expect(pan.value.isApproximatelyEqual(to: 0.0))
    pan.update(1.0)
    #expect(pan.slider == 1.0)
    #expect(pan.value == 1.0)
    pan.update(0.5)
    #expect(pan.slider.isApproximatelyEqual(to: 0.5))
    #expect(pan.value.isApproximatelyEqual(to: 0.5))
    pan.update(-0.25)
    #expect(pan.slider.isApproximatelyEqual(to: -0.25))
    #expect(pan.value.isApproximatelyEqual(to: -0.25))
    pan.update(0.10)
    #expect(pan.slider.isApproximatelyEqual(to: 0.10))
    #expect(pan.value.isApproximatelyEqual(to: 0.10))
    pan.update(0.0)
    #expect(pan.slider.isApproximatelyEqual(to: 0.0))
    #expect(pan.value.isApproximatelyEqual(to: 0.0))
  }
}

