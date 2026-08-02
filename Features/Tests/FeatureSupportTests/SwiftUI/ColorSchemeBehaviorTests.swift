import Testing

@testable import FeatureSupport
import SnapshotTesting

@Suite(
  .snapshots(record: .failed)
)
@MainActor
struct ColorSchemeBehaviorTests {

  @Test(arguments: ColorSchemeBehavior.allCases)
  func id(value: ColorSchemeBehavior) throws {
    #expect(value.id == value)
  }

  @Test(
    arguments: [
      (ColorSchemeBehavior.system, nil),
      (.light, ColorScheme.light),
      (.dark, .dark)
    ]
  )
  func preferredColorScheme(_ behavior: ColorSchemeBehavior, colorScheme: ColorScheme?) throws {
    #expect(behavior.preferredColorScheme == colorScheme)
  }

  @Test(
    arguments: [
      (ColorSchemeBehavior.system, Color.clear),
      (.light, .white),
      (.dark, .black)
    ]
  )
  func rootBackgroundColor(_ behavior: ColorSchemeBehavior, color: Color) throws {
    #expect(behavior.rootBackgroundColor == color)
  }
}
