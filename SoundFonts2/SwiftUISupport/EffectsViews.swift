import AUv3Controls
import SwiftUI

struct TitleOnOff<T1: View, T2: View>: View {
  @Environment(\.auv3ControlsTheme) var theme

  let title: String
  let onOffToggleView: T1
  let globalLockToggleView: T2

  var body: some View {
    VStack(alignment: .leading, spacing: 10) {
      Text(title)
        .foregroundStyle(theme.controlForegroundColor)
        .font(.effectsTitleFont)

      onOffToggleView
      globalLockToggleView
    }
  }
}

struct EffectsContainer<T: View, C: View>: View {
  let titleStack: T
  let contentStack: C
  let enabled: Bool

  init(enabled: Bool, title: T, content: C) {
    self.enabled = enabled
    self.titleStack = title
    self.contentStack = content
  }

  var body: some View {
    HStack(alignment: .top, spacing: 12) {
      titleStack
      contentStack
        .padding(.init(top: 4, leading: 0, bottom: 4, trailing: 0))
        .dimmedAppearanceModifier(enabled: enabled)
    }
    .frame(maxWidth: 102)
    .frame(height: 102)
  }
}
