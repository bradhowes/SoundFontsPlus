// Copyright © 2025 Brad Howes. All rights reserved.

/**
 Collection of enums and types used to represent MIDI v1 values and state. Converted from SF2Lib C++ include.
 */
enum MIDICoreEvent: UInt8 {
  case noteOff = 0x80
  case noteOn = 0x90
  case keyPressure = 0xA0
  case controlChange = 0xB0
  case programChange = 0xC0
  case channelPressure = 0xD0
  case pitchBend = 0xE0
  case systemExclusive = 0xF0
  case timeCodeQuarterFrame = 0xF1
  case songPositionPointer = 0xF2
  case songSelect = 0xF3
  case undefined1 = 0xF4
  case undefined2 = 0xF5
  case tuneRequest = 0xF6
  case EOX = 0xF7
  case timingClock = 0xF8
  case undefined3 = 0xF9
  case undefined4 = 0xFD
  case reset = 0xFF
}

enum MIDIControlChange: UInt8 {
  case bankSelectMSB = 0x00
  case modulationWheelMSB = 0x01
  case breathMSB = 0x02
  case footMSB = 0x04
  case portamentoTimeMSB = 0x05
  case dataEntryMSB = 0x06
  case volumeMSB = 0x07
  case balanceMSB = 0x08
  case panMSB = 0x0A
  case expressionMSB = 0x0B
  case effects1MSB = 0x0C
  case effects2MSB = 0x0D

  case generalPurpose1MSB = 0x10
  case generalPurpose2MSB = 0x11
  case generalPurpose3MSB = 0x12
  case generalPurpose4MSB = 0x13

  case bankSelectLSB = 0x20
  case modulationWheelLSB = 0x21
  case breathLSB = 0x22
  case footLSB = 0x24
  case portamentoTimeLSB = 0x25
  case dataEntryLSB = 0x26
  case volumeLSB = 0x27
  case balanceLSB = 0x28
  case panLSB = 0x2A
  case expressionLSB = 0x2B
  case effects1LSB = 0x2C
  case effects2LSB = 0x2D

  case generalPurpose1LSB = 0x30
  case generalPurpose2LSB = 0x31
  case generalPurpose3LSB = 0x32
  case generalPurpose4LSB = 0x33

  case sustainSwitch = 0x40
  case portamentoSwitch = 0x41
  case sostenutoSwitch = 0x42
  case softPedalSwitch = 0x43
  case legatoSwitch = 0x44
  case hold2Switch = 0x45

  case soundControl1 = 0x46
  case soundControl2 = 0x47
  case soundControl3 = 0x48
  case soundControl4 = 0x49
  case soundControl5 = 0x4A
  case soundControl6 = 0x4B
  case soundControl7 = 0x4C
  case soundControl8 = 0x4D
  case soundControl9 = 0x4E
  case soundControl10 = 0x4F

  case generalPurpose5 = 0x50
  case generalPurpose6 = 0x51
  case generalPurpose7 = 0x52
  case generalPurpose8 = 0x53

  case portamentoControl = 0x54
  case effectsDepth1 = 0x5B
  case effectsDepth2 = 0x5C
  case effectsDepth3 = 0x5D
  case effectsDepth4 = 0x5E
  case effectsDepth5 = 0x5F

  case dataEntryIncrement = 0x60
  case dataEntryDecrement = 0x61

  case nrpnLSB = 0x62
  case nrpnMSB = 0x63
  case rpnLSB = 0x64
  case rpnMSB = 0x65

  // Channel messages
  case allSoundOff = 0x78
  case resetAllControllers = 0x79
  case localControl = 0x7A
  case allNotesOff = 0x7B
  case omniOff = 0x7C
  case omniOn = 0x7D
  case monoOn = 0x7E
  case polyOn = 0x7F
}

/* General MIDI RPN event numbers (LSB MSB = 0) */
enum MIDIRPNEvent: UInt8 {
  case pitchBendRange = 0x00
  case channelFineTune = 0x01
  case channelCoarseTune = 0x02
  case tuningProgramChange = 0x03
  case tuningBankSelect = 0x04
  case modulationDepthRange = 0x05
}
