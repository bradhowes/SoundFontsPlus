import AVKit
import Dependencies
import Foundation
import SQLiteData
import Testing

@testable import SoundFontsPlus

extension BaseTestSuite {

  @MainActor
  struct AVAudioSessionTests {}
}

extension BaseTestSuite.AVAudioSessionTests {

  @Test func monitorVolume() async throws {
    // TODO: create AVAudioSession mock to properly test behavior
    try? AVAudioSession.sharedInstance().setActive(true)
    let value = AVAudioSession.sharedInstance().startStreamingOutputVolume { _ in
      print("terminated")
    }
  }
}
