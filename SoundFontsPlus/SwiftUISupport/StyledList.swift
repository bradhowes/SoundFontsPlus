// Copyright © 2025 Brad Howes. All rights reserved.

import SwiftUI

public struct StyledList<Content: View>: View {
  private let content: Content

  public init(@ViewBuilder _ content: () -> Content) {
    self.content = content()
  }

  public var body: some View {
    ScrollView {
      LazyVStack(alignment: .leading, spacing: 8, pinnedViews: [.sectionHeaders]) {
        content
//            .padding([.leading, .trailing], 8)
//            .padding([.top, .bottom], 4)
      }
      // .listSectionSpacing(.compact)
      // .listStyle(.plain)
      // .environment(\.defaultMinListHeaderHeight, 1)
    }
  }
}

public struct StyledEntry<Content: View>: View {
  private let content: Content

  public init(@ViewBuilder _ content: () -> Content) {
    self.content = content()
  }

  public var body: some View {
    content
      .padding([.leading, .trailing], 8)
      .padding([.top, .bottom], 4)
  }
}

public struct StyledHeader<Content: View>: View {
  private let content: Content

  public init(@ViewBuilder _ content: () -> Content) {
    self.content = content()
  }

  public var body: some View {
    content
      .padding([.top, .bottom], 4)
      .padding([.leading, .trailing], 8)
      .frame(
        minWidth: 0,
        maxWidth: .infinity,
        minHeight: 0,
        maxHeight: .infinity,
        alignment: .topLeading
      )
      .background(.black.opacity(0.75))
      .foregroundStyle(Color.listHeaderForeground)
  }
}
