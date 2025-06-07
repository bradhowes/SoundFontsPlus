// Copyright © 2025 Brad Howes. All rights reserved.

import SwiftUI

public struct DisableWithScreenedContent<Content: View>: View {
  private let content: Content
  private let enabled: Bool

  public init(enabled: Bool, @ViewBuilder _ content: () -> Content) {
    self.enabled = enabled
    self.content = content()
  }

  public var body: some View {
    ZStack {
      content
      Rectangle()
        .fill(.white)
        .padding(.all, -2)
        .blendMode(.screen)
        .opacity(enabled ? 0.0 : 0.5)
        .animation(.smooth, value: enabled)
    }
  }
}

public struct DisableWithScreenedContentModifier: ViewModifier {
  let enabled: Bool
  @Environment(\.colorScheme) var colorScheme

  public func body(content: Content) -> some View {
    ZStack {
      content
        .disabled(!enabled)
      Rectangle()
        .fill(colorScheme == .dark ? .black : .white)
        .padding(.all, -2)
        .blendMode(colorScheme == .dark ? .multiply : .screen)
        .opacity(enabled ? 0.0 : 0.5)
        .animation(.smooth, value: enabled)
    }
  }
}

extension View {
  public func disableWithScreenedContent(enabled: Bool) -> some View {
    modifier(DisableWithScreenedContentModifier(enabled: enabled))
  }
}

#Preview {
  ReverbView.preview
}
