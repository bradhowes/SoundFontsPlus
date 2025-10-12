import AVFAudio
import Foundation
import Testing

@testable import BaseSupport

@Suite(
  //  .dependencies {
  //    $0.defaultDatabase = try appDatabase()
  //  },
  //  .snapshots(record: .failed)
)
struct AVAudioUnitTests {

  @Test func midiInstrument() async throws {
    let no = AVAudioUnitReverb()
    #expect(no.midiInstrument == nil)
    let yes = AVAudioUnitSampler()
    #expect(yes.midiInstrument != nil)
  }
}
