import Testing
import TestSupport

@testable import FeatureSupport

@Suite
@MainActor
struct ColorSchemeBehaviorTests {

  @Test
  func id() throws {
    #expect(ColorSchemeBehavior.system.id == ColorSchemeBehavior.system)
    #expect(ColorSchemeBehavior.light.id == ColorSchemeBehavior.light)
    #expect(ColorSchemeBehavior.dark.id == ColorSchemeBehavior.dark)
  }

  @Test
  func preferredColorScheme() throws {
    #expect(ColorSchemeBehavior.system.preferredColorScheme == nil)
    #expect(ColorSchemeBehavior.light.preferredColorScheme == .light)
    #expect(ColorSchemeBehavior.dark.preferredColorScheme == .dark)
  }

  @Test
  func rootBackgroundColor() throws {
    #expect(ColorSchemeBehavior.system.rootBackgroundColor == .clear)
    #expect(ColorSchemeBehavior.light.rootBackgroundColor == .white)
    #expect(ColorSchemeBehavior.dark.rootBackgroundColor == .black)
  }
}
