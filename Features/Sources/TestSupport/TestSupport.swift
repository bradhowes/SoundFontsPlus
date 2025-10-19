import AVFAudio.AVAudioUnit
import BaseSupport
import Foundation
import SnapshotTesting
import SwiftUI
import Testing

public enum TestSupport {

  static let log = Logger(category: "TestSupport")

  /// A mock of AVAudioSession.outputVolume that toggles between 1.0 and 0.0
  final public class OutputVolumeFlipFlop: @unchecked Sendable {
    public var continuation: AsyncStream<Float>.Continuation?
    public var currentValue: Float = 1.0

    public func getValue() -> Float { self.currentValue }

    /**
     Toggle current value and emit onto the stream.

     - returns: new value
     */
    @discardableResult public func advance() -> Float {
      self.currentValue = 1.0 - self.currentValue
      continuation?.yield(self.currentValue)
      return self.currentValue
    }

    public func startStreaming() -> AsyncStream<Float> {
      AsyncStream<Float> { self.continuation = $0 }
    }

    /**
     Obtain an `OutputVolume` instance that relies on this instance for operation.

     - returns: current value
     */
    public func makeOutputVolume() -> OutputVolume {
      .init(
        getValue: { self.getValue() },
        startStreaming: { self.startStreaming() }
      )
    }

    public init() {}
  }

  @MainActor
  public static func assertSnapshot<V: SwiftUI.View>(
    matching: V,
    size: CGSize = CGSize(width: 400, height: 800),
    colorScheme: ColorScheme = .dark,
    background: Color = .black,
    fileID: StaticString = #fileID,
    file: StaticString = #filePath,
    testName: StaticString = #function,
    line: Int = #line,
    col: Int = #column
  ) throws {
    let uniqueTestName = makeUniqueSnapshotName(testName)
    log.info("assertSnapshot - \(uniqueTestName)")
    for (key, value) in ProcessInfo.processInfo.environment {
      log.info("environment[\(key)]: \(value)")
    }

    let view = SnapshotTestViewWrapper(size: size, colorScheme: colorScheme, background: background) {
      matching
    }

    if let result = SnapshotTesting.verifySnapshot(
      of: view,
      as: .image(
        drawHierarchyInKeyWindow: false,
        layout: .fixed(width: size.width, height: size.height)
      ),
      named: uniqueTestName,
      record: nil,
      snapshotDirectory: nil,
      timeout: 5,
      fileID: fileID,
      file: file,
      testName: "\(testName)",
      line: UInt(line),
      column: UInt(col)
    ) {
      // Only record failures when not runnng in CI pipeline on Github
      if ProcessInfo.processInfo.isOnGithub {
        log.info("*** \(result)")
      } else {
        Issue.record(
          Comment(rawValue: result),
          sourceLocation: .init(fileID: "\(fileID)", filePath: "\(file)", line: line, column: col)
        )
      }
    }
  }

  @inlinable
  static func makeUniqueSnapshotName(_ funcName: StaticString) -> String {
#if os(iOS)
    "\(funcName)-iOS"
#endif // os(iOS)
#if os(macOS)
    "\(funcName)-macOS"
#endif // os(macOS)
  }

  struct SnapshotTestViewWrapper<Content: View>: View {
    let size: CGSize
    let content: Content
    let colorScheme: ColorScheme
    let background: Color

    public init(size: CGSize, colorScheme: ColorScheme, background: Color?,  @ViewBuilder _ content: () -> Content) {
      self.size = size
      self.content = content()
      self.colorScheme = colorScheme
      self.background = background ?? (colorScheme == .dark ? .black : .white)
    }

    public var body: some View {
      Group {
        content
      }
      .frame(width: size.width, height: size.height)
      .background(background)
      .environment(\.colorScheme, colorScheme)
    }
  }

  public final class MockAudioUnit: AVAudioUnitSampler, @unchecked Sendable {
    public var events: [(MIDICoreEvent, UInt8, UInt8, UInt8)] = []

    public override func startNote(_ note: UInt8, withVelocity velocity: UInt8, onChannel channel: UInt8) {
      events.append((.noteOn, note, velocity, channel))
    }

    public override func stopNote(_ note: UInt8, onChannel channel: UInt8) {
      events.append((.noteOff, note, 0, channel))
    }

    public override func sendPressure(forKey note: UInt8, withValue pressure: UInt8, onChannel channel: UInt8) {
      events.append((.keyPressure, note, pressure, channel))
    }
    public override func sendController(_ controller: UInt8, withValue value: UInt8, onChannel channel: UInt8) {
      events.append((.controlChange, controller, value, channel))
    }
    public override func sendProgramChange(_ program: UInt8, onChannel channel: UInt8) {
      events.append((.programChange, program, 0, channel))
    }
    public override func sendPressure(_ pressure: UInt8, onChannel channel: UInt8) {
      events.append((.channelPressure, pressure, 0, channel))
    }
    public override func sendPitchBend(_ value: UInt16, onChannel channel: UInt8) {
      events.append((.pitchBend, UInt8(value & 0x7F), UInt8(value >> 7), channel))
    }
    public override func reset() {
      events.append((.reset, 0, 0, 0))
    }
  }
}
