// Copyright © 2025 Brad Howes. All rights reserved.

import AVFAudio
import BaseSupport
import Foundation
import Dependencies
import DependenciesTestSupport
import Sharing
import Testing
import TestSupport

@testable import SF2LibAU

@Suite(
  .dependencies {
    // TODO: use mock here
    $0.audioGraph = .liveValue
    $0.audioSession = .liveValue
    $0.continuousClock = .immediate
    $0.defaultDatabase = TestSupport.testDatabase()
    $0.synthAUv3ComponentDescription = SynthAUv3ComponentDescription.testValue
  },
  .snapshots(record: .failed),
  .serialized
)
@MainActor
struct SF2LibAUTests {

}
