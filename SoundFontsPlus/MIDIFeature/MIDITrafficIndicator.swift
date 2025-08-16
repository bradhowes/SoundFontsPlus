// Copyright © 2025 Brad Howes. All rights reserved.

import Combine
import ComposableArchitecture
import SwiftUI

@Reducer
public struct MIDITrafficIndicatorFeature {

  @ObservableState
  public struct State: Equatable {
    public static func == (lhs: MIDITrafficIndicatorFeature.State, rhs: MIDITrafficIndicatorFeature.State) -> Bool {
      lhs.tag == rhs.tag && lhs.midiTrafficPublisher === rhs.midiTrafficPublisher
    }

    let tag: String
    let midiTrafficPublisher: PassthroughSubject<MIDITraffic, Never> = .init()

    public init(tag: String) {
      self.tag = tag
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
    @Shared(.midiMonitor) var midiMonitor
    guard let midiMonitor else { return .none }
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
    state.midiTrafficPublisher.send(value)
    return .none
  }
}

public struct MIDITrafficIndicatorView: View {
  private var store: StoreOf<MIDITrafficIndicatorFeature>

  public init(store: StoreOf<MIDITrafficIndicatorFeature>) {
    self.store = store
  }

  public var body: some View {
    Circle()
      .trafficBlinker(tag: store.tag, subscribedTo: store.midiTrafficPublisher, duration: 0.5)
  }
}

/**
 Blink a dot to show MIDI traffic. If the channel of the MIDI source is accepted, then show in the accent color
 Otherwise, show in orange/red.
 */
public struct MIDITrafficBlinker<T: Publisher>: ViewModifier where T.Output == MIDITraffic, T.Failure == Never {
  private let tag: String
  @State private var isAnimating = false
  @State private var color: Color = .clear

  var publisher: T
  var duration: Double

  public init(tag: String, subscribedTo publisher: T, duration: Double = 1) {
    self.tag = tag
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
    tag: String,
    subscribedTo publisher: T,
    duration: Double = 1
  ) -> some View where T.Output == MIDITraffic, T.Failure == Never {
    modifier(MIDITrafficBlinker(tag: tag, subscribedTo: publisher, duration: duration))
  }
}

public struct MIDITrafficFlasher<T: Publisher>: ViewModifier where T.Output == MIDITraffic, T.Failure == Never {
  private let tag: String
  @State private var isAnimating = false
  @State private var color: Color = .clear

  var publisher: T
  var duration: Double

  public init(tag: String, subscribedTo publisher: T, duration: Double = 1) {
    self.tag = tag
    self.publisher = publisher
    self.duration = duration
  }

  public func body(content: Content) -> some View {
    content
      .background(color)
      .animation(
        .smooth(duration: duration),
        value: isAnimating
      )
      .onReceive(publisher) { traffic in
        self.color = traffic.accepted ? .accentColor : .orange
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
  public func trafficFlasher<T: Publisher>(
    tag: String,
    subscribedTo publisher: T,
    duration: Double = 1
  ) -> some View where T.Output == MIDITraffic, T.Failure == Never {
    modifier(MIDITrafficFlasher(tag: tag, subscribedTo: publisher, duration: duration))
  }
}
