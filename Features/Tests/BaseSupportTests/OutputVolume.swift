import Testing

@testable import BaseSupport

@Suite
struct OutputVolumeTests {

  @Test func attributes() async throws {
    let uat = OutputVolume.liveValue
    #expect(uat.getValue() > -1.0)
    #expect(throws: Never.self) {
      let stream = uat.startStreaming()
      _ = stream.makeAsyncIterator()
    }
  }
}
