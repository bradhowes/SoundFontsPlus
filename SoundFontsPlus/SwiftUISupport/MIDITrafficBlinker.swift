// Copyright © 2025 Brad Howes. All rights reserved.

import Combine
import SwiftUI

/**
 Dim content of a view when not enabled.
 */
public struct MIDITrafficBlinker: ViewModifier {
  @State private var isAnimating = false
  var publisher: AnyPublisher<Void, Never>
  var color: Color
  var duration: Double

  public init(subscribedTo publisher: AnyPublisher<Void, Never>, color: Color, duration: Double = 1) {
    self.publisher = publisher
    self.color = color
    self.duration = duration
  }

  public func body(content: Content) -> some View {
    content
      .foregroundStyle(color)
      .frame(width: 24, height: 24)
      .scaleEffect(isAnimating ? 1.0 : 0.01)
      .opacity(isAnimating ? 0.0 : 1.0)
      .animation(
        .smooth(duration: duration),
        value: isAnimating
      )
      .onReceive(publisher) { _ in
        withAnimation(.linear(duration: self.duration / 2)) {
          self.isAnimating = true
          DispatchQueue.main.asyncAfter(deadline: .now() + self.duration / 2) {
            self.isAnimating = false
          }
        }
      }
  }
}

extension View {
  public func trafficBlinker<T: Publisher>(
    subscribedTo publisher: T,
    color: Color,
    duration: Double = 1
  ) -> some View where T.Output == Void, T.Failure == Never {
    modifier(MIDITrafficBlinker(subscribedTo: publisher.eraseToAnyPublisher(), color: color, duration: duration))
  }
}

#Preview {
  DelayView.preview
}
