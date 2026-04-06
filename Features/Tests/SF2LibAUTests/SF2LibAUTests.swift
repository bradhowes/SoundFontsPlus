// Copyright © 2025 Brad Howes. All rights reserved.

import AVFAudio
import BaseSupport
import DependenciesTestSupport
import Foundation
import Engine
import Testing
import TestSupport

@testable import SF2LibAU

// SF2LibAU cannot be tested via the SF2LibAU API since it actually creates
@Suite
@MainActor
struct SF2LibAUTests {

  @Test
  func engineTests() async throws {
    var engine = SF2Engine()
    engine.create(48000.0, 16)

    _ = SF2Engine.createResetCommandPayload()
    _ = SF2Engine.createUseBankProgramPayload(1, 2)
    _ = SF2Engine.createChannelMessagePayload(1, 2)
    _ = SF2Engine.createAllSoundOffPayload()
    _ = SF2Engine.createAllNotesOffPayload()

    #expect(engine.activePresetName() == "")
    #expect(engine.activeVoiceCount() == 0)
    #expect(engine.monophonicModeEnabled() == false)
    #expect(engine.polyphonicModeEnabled() == true)
    #expect(engine.portamentoModeEnabled() == false)
    #expect(engine.oneVoicePerKeyModeEnabled() == false)
    #expect(engine.retriggerModeEnabled() == true)
  }
}
