// Copyright © 2025 Brad Howes. All rights reserved.

public import AVFAudio.AVAudioUnitMIDIInstrument
public import Foundation
import Engine

extension AVAudioUnitMIDIInstrument {

  /**
   Create a custom SysEx MIDI message to load an SF2 file and activate a specific preset. Send it to the SF2LibAU audio unit.

   - parameter path: the path to the SF2 file to load
   - parameter preset: the index of the preset to activate
   - returns: `true` if successfully sent message
   */
  public func sendLoadFileUsePreset(path: String, preset: Int) -> Bool {
    sendMIDI(bytes: Array(SF2Engine.createLoadFileUsePresetPayload(std.string(path), preset)))
  }

  /**
   Create a custom SysEx MIDI message to load an SF2 file **bookmark** and activate a specific preset. Send it to the SF2LibAU
   audio unit.

   - parameter bookmark: the bookmark pointing to the SF2 file to load
   - parameter preset: the index of the preset to activate
   - returns: `true` if successfully sent message
   */
  public func sendLoadBookmarkUsePreset(bookmark: Data, preset: Int) -> Bool {
    sendMIDI(bytes: Array(SF2Engine.createLoadBookmarkUsePresetPayload(bookmark, preset)))
  }

  /**
   Create a custom SysEx message to change the active preset of an already-loaded SF2 file. Send it to the SF2LibAU autio unit.

   - parameter preset: the index of the preset to activate
   - returns: `true` if successfully sent message
   */
  public func sendUsePreset(preset: Int) -> Bool {
    sendMIDI(bytes: Array(SF2Engine.createLoadFileUsePresetPayload("", preset)))
  }

  /**
   Create a MIDI commands to turn off all notes and to perform a reset. Send it to the SF2LibAU autio unit.

   - returns: `true` if successfully sent messages
   */
  public func sendReset() -> Bool {
    [
      sendMIDI(bytes: Array(SF2Engine.createAllNotesOffPayload())),
      sendMIDI(bytes: Array(SF2Engine.createResetCommandPayload()))
    ].allSatisfy { $0 }
  }

  public func sendMIDI(bytes: [UInt8], when: AUEventSampleTime = 0, cable: UInt8 = 0) -> Bool {
    guard let block = unsafe auAudioUnit.scheduleMIDIEventBlock else {
      return false
    }
    unsafe block(when, cable, bytes.count, bytes)
    return true
  }
}
