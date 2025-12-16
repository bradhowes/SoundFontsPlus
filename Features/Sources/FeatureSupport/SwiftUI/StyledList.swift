// Copyright © 2025 Brad Howes. All rights reserved.

import SwiftUI

public struct StyledList<Content: View>: View {
  private let content: Content

  public init(@ViewBuilder _ content: () -> Content) {
    self.content = content()
  }

#if os(iOS)
  public var body: some View {
    List {
      content
    }
    .listSectionSpacing(.compact)
    .listStyle(.plain)
  }
#endif // os(iOS)

#if os(macOS)
  public var body: some View {
    List {
      content
    }
    .listStyle(.plain)
  }
#endif // os(macOS)
}

public struct StyledEntry<Content: View>: View {
  private let content: Content

  public init(@ViewBuilder _ content: () -> Content) {
    self.content = content()
  }

  public var body: some View {
    content
  }
}

public struct StyledHeader<Content: View>: View {
  private let content: Content

  public init(@ViewBuilder _ content: () -> Content) {
    self.content = content()
  }

  public var body: some View {
    content
      // .padding([.top, .bottom], 8)
      .frame(
        minWidth: 0,
        maxWidth: .infinity,
        minHeight: 0,
        maxHeight: .infinity,
        alignment: .topLeading
      )
      // .background(.black.opacity(0.75))
      .foregroundStyle(Color.listHeaderForeground)
  }
}
