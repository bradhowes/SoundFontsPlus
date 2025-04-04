import SwiftUI

public struct StyledList<Content: View>: View {
  private let content: Content

  public init(@ViewBuilder _ content: () -> Content) {
    self.content = content()
  }

  public var body: some View {
    List {
      content
    }
    .listSectionSpacing(.compact)
    .listStyle(.plain)
    .environment(\.defaultMinListHeaderHeight, 1)
  }
}
