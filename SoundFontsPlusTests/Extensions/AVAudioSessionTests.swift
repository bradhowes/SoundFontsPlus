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

  @objc class VolumeProvider: NSObject, OutputVolumeStream {
    @objc dynamic var outputVolume: AUValue = 0.0
  }

  @Test func monitorVolume() async throws {
    let bits = AVAudioSession.sharedInstance().startStreamingOutputVolume { _ in
      print("terminated")
    }
    print(bits)
  }

  @Test func outputVolumeStream() async throws {
    let volumeProvider = VolumeProvider()
    let changeTask = Task {
      var value = 0.1
      while true {
        volumeProvider.outputVolume = AUValue(value)
        value += 0.1
        try await Task.sleep(for: .milliseconds(10))
      }
    }

    var saw = [AUValue]()
    let bits = volumeProvider.start()
    for await value in bits.1 {
      saw.append(value)
      if saw.count == 10 {
        break
      }
    }

    changeTask.cancel()
    #expect(saw.count == 10)
    print(saw)
  }
}
