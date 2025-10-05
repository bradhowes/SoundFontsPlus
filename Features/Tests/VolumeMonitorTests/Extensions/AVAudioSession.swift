import AVKit
import Combine
import Dependencies
import Foundation
import SQLiteData
import Testing

@testable import VolumeMonitor

extension BaseTestSuite {

  @MainActor
  struct AVAudioSessionTests {}
}

@objc final class VolumeProvider: NSObject, OutputVolumeStream, @unchecked Sendable {
  @objc dynamic private(set) var outputVolume: Float = 0.0

  func setOutputVolume(_ value: Float) {
    self.outputVolume = value
  }
}

extension BaseTestSuite.AVAudioSessionTests {

  @Test func monitorVolume() async throws {
    let bits = AVAudioSession.sharedInstance().startStreamingOutputVolume()
    print(bits)
  }

  @Test func outputVolumeStream() async throws {
    let volumeProvider = VolumeProvider()
    let stream = volumeProvider.startStreaming()

    let changeTask = Task {
      var value = 0.1
      while true {
        volumeProvider.setOutputVolume(AUValue(value))
        value += 0.1
        try await Task.sleep(for: .milliseconds(10))
      }
    }

    var saw = [AUValue]()
    for await value in stream {
      print("value:", value)
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
