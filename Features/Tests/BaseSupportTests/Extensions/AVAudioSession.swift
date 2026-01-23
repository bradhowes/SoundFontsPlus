// Copyright © 2025 Brad Howes. All rights reserved.

import AVKit
import Dependencies
import Foundation
import Models
import SQLiteData
import Testing

@testable import BaseSupport

@objc final class VolumeProvider: NSObject, OutputVolumeStream, @unchecked Sendable {
  @objc dynamic private(set) var outputVolume: Float = 0.0

  func setOutputVolume(_ value: Float) {
    self.outputVolume = value
  }
}

@Suite
@MainActor
struct AVAudioSessionTests {

  @Test
  func monitorVolume() async throws {
    let bits = AVAudioSession.sharedInstance().startStreamingOutputVolume()
    print(bits)
  }

  @Test
  func outputVolumeStream() async throws {
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
