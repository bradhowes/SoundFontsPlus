// Copyright © 2026 Brad Howes. All rights reserved.

import SwiftUI

public struct HelpInfoLayout: Layout {
  public let spacing: CGFloat

  public init(spacing: CGFloat = 16.0) {
    self.spacing = spacing
  }

  public func sizeThatFits(proposal: ProposedViewSize, subviews: Subviews, cache: inout ()) -> CGSize {
    guard !subviews.isEmpty else { return .zero }
    var width: CGFloat = 0
    var height: CGFloat = 0
    for subview in subviews {
      let unlimited = subview.sizeThatFits(ProposedViewSize.unspecified)
      let limited = subview.sizeThatFits(proposal)
      width = max(width, min(unlimited.width, limited.width))
      height += limited.height + spacing
    }
    return .init(width: width, height: height - spacing)
  }

  public func placeSubviews(in bounds: CGRect, proposal: ProposedViewSize, subviews: Subviews, cache: inout ()) {
    let size = sizeThatFits(proposal: proposal, subviews: subviews, cache: &cache)
    let actual = ProposedViewSize(width: size.width, height: nil)
    var height: CGFloat = bounds.minY
    for subview in subviews {
      let limited = subview.sizeThatFits(actual)
      subview.place(at: .init(x: bounds.minX, y: height), anchor: .topLeading, proposal: actual)
      height += limited.height + spacing
    }
  }
}

#Preview {
  VStack(spacing: 8) {
    VStack {
      HelpInfoLayout {
        Text("Another Title")
          .font(.title3.weight(.bold))
        Text("The quick brown fox.")
          .font(.footnote)
      }
      HStack(spacing: 24) {
        Button {
        } label: {
          Image(systemName: "arrowshape.left.fill")
        }
        Button {
        } label: {
          Image(systemName: "arrowshape.right.fill")
        }
      }
      .fontWeight(.semibold)
    }
    // .frame(maxWidth: 240)
    .border(.black, width: 2)
    .background(.yellow)
    VStack {
      HelpInfoLayout {
        Text("Title")
          .font(.title3.weight(.bold))
        Text(
"""
The quick brown fox jumped over the lazy fox. \
The quick brown fox jumped over the lazy fox. \
The quick brown fox jumped over the lazy fox.
"""
        )
        .font(.footnote)
      }
      HStack(spacing: 24) {
        Button {
        } label: {
          Image(systemName: "arrowshape.left.fill")
        }
        Button {
        } label: {
          Image(systemName: "arrowshape.right.fill")
        }
     }
      .fontWeight(.semibold)
    }
    .frame(maxWidth: 320)
    .border(.black, width: 2)
    .background(.yellow)
  }
}
