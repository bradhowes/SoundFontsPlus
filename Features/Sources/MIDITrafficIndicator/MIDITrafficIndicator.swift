// Copyright © 2025 Brad Howes. All rights reserved.

import AsyncAlgorithms
import BaseSupport
public import CasePaths
public import Combine
public import ComposableArchitecture
public import FeatureSupport

@Reducer
public struct MIDITrafficIndicator {

  @ObservableState
  public struct State: Equatable {
    public static func == (lhs: MIDITrafficIndicator.State, rhs: MIDITrafficIndicator.State) -> Bool {
      lhs.tag == rhs.tag && lhs.midiTrafficPublisher === rhs.midiTrafficPublisher
    }

    public let tag: String
    public let midiTrafficPublisher: PassthroughSubject<MIDITrafficStat, Never> = .init()

    public init(tag: String) {
      self.tag = tag
    }
  }

  public enum Action {
    case deinitialize
    case initialize
    case showMIDITraffic(MIDITrafficStat)
  }

  public init() {}

  public var body: some ReducerOf<Self> {
    Reduce<State, Action> { state, action in
      switch action {
      case .deinitialize: return .merge(CancelId.allCases.map { .cancel(id: $0) })
      case .initialize: return initialize(&state)
      case .showMIDITraffic(let traffic): return showMIDITraffic(&state, value: traffic)
      }
    }
  }

  private enum CancelId: String, CaseIterable {
    case midiTrafficIndicatorMonitorMIDITraffic
  }
}

extension MIDITrafficIndicator {

  private func initialize(_ state: inout State) -> Effect<Action> {
    monitorMIDITraffic(&state)
  }

  private func monitorMIDITraffic(_ state: inout State) -> Effect<Action> {
    @Shared(.midiMonitor) var midiMonitor
    guard let midiMonitor else { return .none }
    return .run { send in
      for await event in midiMonitor.$traffic.values.compacted() {
        await send(.showMIDITraffic(event))
      }
    }.cancellable(id: CancelId.midiTrafficIndicatorMonitorMIDITraffic)
  }

  private func showMIDITraffic(_ state: inout State, value: MIDITrafficStat) -> Effect<Action> {
    state.midiTrafficPublisher.send(value)
    return .none
  }
}

public struct MIDITrafficIndicatorView: View {
  private var store: StoreOf<MIDITrafficIndicator>

  public init(store: StoreOf<MIDITrafficIndicator>) {
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
public struct MIDITrafficBlinker<T: Publisher>: ViewModifier where T.Output == MIDITrafficStat, T.Failure == Never {
  private let tag: String
  @State private var isAnimating = false
  @State private var color: Color = .clear
  @Dependency(\.mainQueue) private var mainQueue

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
      .scaleEffect(isAnimating ? 1.0 : 0.1)
      .opacity(isAnimating ? 0.5 : 0.0)
      .onReceive(publisher.throttle(for: .seconds(self.duration), scheduler: mainQueue, latest: false)) { traffic in
        self.color = traffic.accepted ? .green : .orange
        withAnimation(.smooth(duration: self.duration / 2)) {
          self.isAnimating = true
        } completion: {
          withAnimation(.smooth(duration: self.duration / 2)) {
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
  ) -> some View where T.Output == MIDITrafficStat, T.Failure == Never {
    modifier(MIDITrafficBlinker(tag: tag, subscribedTo: publisher, duration: duration))
  }
}

private let log: Logger = .init(category: "MIDITrafficIndicator")
