// Copyright © 2025 Brad Howes. All rights reserved.

import Combine
import ComposableArchitecture
import SwiftUI

@Reducer
public struct MIDITrafficIndicatorFeature {

  @ObservableState
  public struct State {
    let tag: String
    let midiMonitor: MIDIMonitor?
    var trafficPublisher: PassthroughSubject<MIDITraffic, Never> = .init()

    public init(tag: String, midiMonitor: MIDIMonitor?) {
      self.tag = tag
      self.midiMonitor = midiMonitor
    }
  }

  public enum Action {
    case initialize
    case showMIDITraffic(MIDITraffic)
  }

  public var body: some ReducerOf<Self> {
    Reduce<State, Action> { state, action in
      switch action {
      case .initialize: return initialize(&state)
      case .showMIDITraffic(let traffic): return showMIDITraffic(&state, value: traffic)
      }
    }
  }

  private enum CancelId {
    case monitorMIDITraffic
  }
}

private extension MIDITrafficIndicatorFeature {
  func initialize(_ state: inout State) -> Effect<Action> {
    monitorMIDITraffic(&state)
  }

  func monitorMIDITraffic(_ state: inout State) -> Effect<Action> {
    guard let midiMonitor = state.midiMonitor else { return .none }
    return .run { send in
      for await traffic in midiMonitor.$traffic
        .compactMap({$0})
        // .buffer(size: 1, prefetch: .byRequest, whenFull: .dropOldest)
        .values {
        await send(.showMIDITraffic(traffic))
      }
    }.cancellable(id: CancelId.monitorMIDITraffic)
  }

  func showMIDITraffic(_ state: inout State, value: MIDITraffic) -> Effect<Action> {
    state.trafficPublisher.send(value)
    return .none
  }
}

public struct MIDITrafficIndicator<T: Publisher>: View where T.Output == MIDITraffic, T.Failure == Never {
  @State private var trafficPublisher: T

  public init(trafficPublisher: T) {
    self.trafficPublisher = trafficPublisher
  }

  public var body: some View {
    Circle()
      .trafficBlinker(subscribedTo: trafficPublisher, duration: 0.5)
  }
}

/**
 Blink a dot to show MIDI traffic. If the channel of the MIDI source is accepted, then show in the accent color
 Otherwise, show in orange/red.
 */
public struct MIDITrafficBlinker<T: Publisher>: ViewModifier where T.Output == MIDITraffic, T.Failure == Never {
  @State private var isAnimating = false
  @State private var color: Color = .clear

  var publisher: T
  var duration: Double

  public init(subscribedTo publisher: T, duration: Double = 1) {
    self.publisher = publisher
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
      .onReceive(publisher) { traffic in
        self.color = traffic.accepted ? .green : .orange
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
    duration: Double = 1
  ) -> some View where T.Output == MIDITraffic, T.Failure == Never {
    modifier(MIDITrafficBlinker(subscribedTo: publisher, duration: duration))
  }
}
