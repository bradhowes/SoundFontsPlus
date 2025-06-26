// Copyright © 2025 Brad Howes. All rights reserved.

import SwiftUI

public struct StyledList<Content: View>: View {
  private let title: String?
  private let content: Content

  public init(title: String, @ViewBuilder _ content: () -> Content) {
    self.title = title
    self.content = content()
  }

  public init(@ViewBuilder _ content: () -> Content) {
    self.title = nil
    self.content = content()
  }

  public var body: some View {
    List {
      if let title {
        let header = Text(title)
          .foregroundStyle(.indigo)
        Section(header: header) {
          content
        }
      } else {
        content
      }
    }
    .listSectionSpacing(.compact)
    .listStyle(.plain)
    .environment(\.defaultMinListHeaderHeight, 1)
  }
}
