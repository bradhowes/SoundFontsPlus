import AVFAudio.AVAudioSession
import Foundation
import Testing

@testable import BaseSupport

@Suite(
  //  .dependencies {
  //    $0.defaultDatabase = try appDatabase()
  //  },
  //  .snapshots(record: .failed)
)
struct AudioSessionTests {

  @Test func liveClient() throws {
    let uat = AudioSession.liveValue
    #expect(throws: Never.self) {
      try uat.setCategory(
        AVAudioSession.Category.playback,
        AVAudioSession.Mode.default,
        [AVAudioSession.CategoryOptions.allowAirPlay]
      )
    }
    #expect(uat.sampleRate() >= 48_000)
    #expect(throws: Never.self) {
      try uat.setPreferredSampleRate(48_000)
    }
    #expect(throws: Never.self) {
      try uat.setPreferredIOBufferDuration(0.01)
    }
    #expect(uat.currentRoute().inputs.count == 0)
    #expect(throws: Never.self) {
      try uat.setActive(false, [])
    }
  }
}
