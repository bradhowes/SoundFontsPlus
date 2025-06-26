// Copyright © 2025 Brad Howes. All rights reserved.

import SwiftUI

public struct SimultaneousLongPressGestureModifier: ViewModifier {
  let minimumDuration: Double
  let action: () -> Void

  public func body(content: Content) -> some View {
    content
      .simultaneousGesture(LongPressGesture(minimumDuration: minimumDuration).onEnded { _ in action() })
  }
}

extension View {
  public func withLongPressGesture(minimumDuration: Double = 0.75, _ action: @escaping () -> Void) -> some View {
    modifier(SimultaneousLongPressGestureModifier(minimumDuration: minimumDuration, action: action))
  }
}

struct PreviewButtonList: View {
  @State var msg: String = ""

  var body: some View {
    List {
      ForEach(1..<6) { index in
        Button("Button \(index)") { setMsg("button \(index) tapped") }
          .withLongPressGesture { setMsg("button \(index) long press") }
      }
    }
    Text(msg)
  }

  func setMsg(_ value: String) {
    self.msg = value
    DispatchQueue.main.asyncAfter(deadline: .now() + 3) {
      self.msg = ""
    }
  }
}

#Preview {
  PreviewButtonList()
}
