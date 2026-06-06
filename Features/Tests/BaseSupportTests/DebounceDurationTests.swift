import BaseSupport
import Dependencies
import Testing

@Suite
struct DebounceDurationTests {

  @Test func testValue() async throws {
    @Dependency(\.debounceDurations) var dd
    #expect(dd.effectsConfigurationSaves == .milliseconds(1000))
    #expect(dd.effectsDisplayUpdates == .milliseconds(100))
  }

  @Test func liveValue() async throws {
    let dd = DebounceDurations.liveValue
    #expect(dd.effectsConfigurationSaves == .milliseconds(1000))
    #expect(dd.effectsDisplayUpdates == .milliseconds(100))
  }

  @Test func previewValue() async throws {
    let dd = DebounceDurations.previewValue
    #expect(dd.effectsConfigurationSaves == .milliseconds(1000))
    #expect(dd.effectsDisplayUpdates == .milliseconds(100))
  }
}
