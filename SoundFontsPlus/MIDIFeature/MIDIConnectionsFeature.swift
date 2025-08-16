// Copyright © 2025 Brad Howes. All rights reserved.

import Combine
import ComposableArchitecture
import CoreMIDI
@preconcurrency import MorkAndMIDI
import SharingGRDB
import SwiftUI

public struct MIDIConnectionRow: Equatable, Identifiable {
  public let id: MIDIUniqueID
  public let displayName: String
  public var channel: UInt8
  public var fixedVolume: Int
  public var autoConnect: Bool

  public init(id: MIDIUniqueID, displayName: String, channel: UInt8) {
    self.id = id
    self.displayName = displayName
    self.channel = channel

    @Dependency(\.defaultDatabase) var database
    if let config = ((try? database.read {
      try MIDIConfig.all.where({$0.uniqueId.eq(id)}).fetchAll($0)
    }) ?? []).first {
      self.fixedVolume = config.fixedVolume
      self.autoConnect = config.autoConnect
    } else {
      self.fixedVolume = 128
      self.autoConnect = false
    }
  }

  func saveConfig() {
    @Dependency(\.defaultDatabase) var database
    withErrorReporting {
      try database.write { db in
        try MIDIConfig.upsert {
          .init(uniqueId: self.id, autoConnect: self.autoConnect, fixedVolume: self.fixedVolume)
        }.execute(db)
      }
    }
  }
}

public struct MIDIConnectionRowView: View {
  @State var row: MIDIConnectionRow

  public init(row: MIDIConnectionRow) {
    self.row = row
  }

  public var body: some View {
    Text("\(row.displayName)")
      .frame(maxWidth: .infinity)
    Text("\(row.channel)")
    HStack(spacing: 0) {
      Text(row.fixedVolume == 128 ? "Off" : "\(row.fixedVolume)")
      Button {
        row.fixedVolume -= 1
      } label: {
        Image(systemName: "arrowtriangle.down")
          .frame(width: 40, height: 40)
      }
      .offset(x: 6)
      .disabled(row.fixedVolume == 1)
      .buttonRepeatBehavior(.enabled)
      Button {
        row.fixedVolume += 1
      } label: {
        Image(systemName: "arrowtriangle.up")
          .frame(width: 40, height: 40)
      }
      .disabled(row.fixedVolume == 128)
      .buttonRepeatBehavior(.enabled)
    }
    .offset(x: 8)
    Button {
      row.autoConnect.toggle()
    } label: {
      Image(systemName: row.autoConnect ? "checkmark.circle.fill" : "circle")
        .frame(width: 40, height: 40)
    }
  }
}

@Reducer
public struct MIDIConnectionsFeature {

  @ObservableState
  public struct State: Equatable {
    var rows: IdentifiedArrayOf<MIDIConnectionRow>
    var trafficIndicator: MIDITrafficIndicatorFeature.State = .init(tag: "MIDI Connections")
    @ObservationStateIgnored
    var midiChannelsCache: [MIDIUniqueID: UInt8] = [:]

    public init() {
      @Shared(.midi) var midi
      let connections = midi?.sourceConnections ?? []
      self.rows = .init(
        uniqueElements: connections.map {
          .init(id: $0.uniqueId, displayName: $0.displayName, channel: 255)
        }
      )
    }
  }

  public enum Action {
    case autoConnectToggleTapped(MIDIUniqueID)
    case fixedVolumeDecrementTapped(MIDIUniqueID)
    case fixedVolumeIncrementTapped(MIDIUniqueID)
    case initialize
    case midiConnectionsChanged
    case sawMIDITraffic(MIDITraffic)
    case trafficIndicator(MIDITrafficIndicatorFeature.Action)
  }

  public var body: some ReducerOf<Self> {

    Scope(state: \.trafficIndicator, action: \.trafficIndicator) { MIDITrafficIndicatorFeature() }

    Reduce { state, action in
      switch action {
      case .autoConnectToggleTapped(let id):
        if let index = state.rows.index(id: id) {
          state.rows[index].autoConnect.toggle()
        }
        return .none

      case .fixedVolumeDecrementTapped(let id): return decrementFixedVolume(&state, id: id)
      case .fixedVolumeIncrementTapped(let id): return incrementFixedVolume(&state, id: id)
      case .initialize: return initialize(&state)
      case .midiConnectionsChanged: return updateMidiConnections(&state)
      case .sawMIDITraffic(let traffic): return updateMIDIChannel(&state, traffic: traffic)
      case .trafficIndicator: return .none
      }
    }
  }

  @Shared(.midi) var midi

  private enum CancelId {
    case monitorMIDIConnections
  }
}

extension MIDIConnectionsFeature {

  private func updateMIDIChannel(_ state: inout State, traffic: MIDITraffic) -> Effect<Action> {
    state.midiChannelsCache[traffic.id] = traffic.channel
    if let index = state.rows.index(id: traffic.id) {
      state.rows[index].channel = traffic.channel
    }
    return .none
  }

  private func decrementFixedVolume(_ state: inout State, id: MIDIUniqueID) -> Effect<Action> {
    if let index = state.rows.index(id: id) {
      state.rows[index].fixedVolume -= 1
    }
    return .none
  }

  private func incrementFixedVolume(_ state: inout State, id: MIDIUniqueID) -> Effect<Action> {
    if let index = state.rows.index(id: id) {
      state.rows[index].fixedVolume += 1
    }
    return .none
  }

  private func initialize(_ state: inout State) -> Effect<Action> {
    .merge(
      reduce(into: &state, action: .trafficIndicator(.initialize)),
      monitorMIDIConnections(&state)
    )
  }

  private func monitorMIDIConnections(_ state: inout State) -> Effect<Action> {
    guard let midi else { return .none }
    return .run { send in
      for await _ in midi.publisher(for: \.activeConnections)
        .buffer(size: 1, prefetch: .byRequest, whenFull: .dropOldest)
        .map({ $0.count })
        .values {
        await send(.midiConnectionsChanged)
      }
    }.cancellable(id: CancelId.monitorMIDIConnections)
  }

  private func updateMidiConnections(_ state: inout State) -> Effect<Action> {
    guard let midi else { return .none }
    state.rows = .init(
      uniqueElements: midi.sourceConnections.map {
        .init(
          id: $0.uniqueId,
          displayName: $0.displayName,
          channel: state.midiChannelsCache[$0.uniqueId] ?? 255
        )
      }
    )
    return .none
  }
}

public struct MIDIConnectionsView: View {
  private var store: StoreOf<MIDIConnectionsFeature>
  @State private var animating: MIDIUniqueID?

  public init(store: StoreOf<MIDIConnectionsFeature>) {
    self.store = store
  }

  public var body: some View {
    ScrollView {
      LazyVGrid(columns: [
        GridItem(.flexible(minimum: 20, maximum: .infinity)),
        GridItem(.fixed(40)),
        GridItem(.fixed(120)),
        GridItem(.fixed(40))
      ], spacing: 0) {
        Text("Name")
          .frame(maxWidth: .infinity)
          .font(.footnote)
          .foregroundStyle(.secondary)
        Text("Ch")
          .font(.footnote)
          .foregroundStyle(.gray)
        Text("Fixed Velocity")
          .font(.footnote)
          .foregroundStyle(.gray)
        Text("Active")
          .font(.footnote)
          .foregroundStyle(.gray)

        ForEach(store.rows) { row in
          Text("\(row.displayName)")
            .frame(maxWidth: .infinity)
            .foregroundStyle(animating == row.id ? Color.accentColor : .primary)
            .scaleEffect(animating == row.id ? 1.25 : 1.0)

          Text(row.channel == 255 ? "-" : "\(row.channel)")
            .frame(maxWidth: .infinity)

          HStack(spacing: 0) {
            Text(row.fixedVolume == 128 ? "Off" : "\(row.fixedVolume)")
              .padding([.leading], 8)
            Button {
              store.send(.fixedVolumeDecrementTapped(row.id))
            } label: {
              Image(systemName: "arrowtriangle.down")
                .frame(width: 30, height: 40)
            }
            .disabled(row.fixedVolume == 1)
            .buttonRepeatBehavior(.enabled)

            Button {
              store.send(.fixedVolumeIncrementTapped(row.id))
            } label: {
              Image(systemName: "arrowtriangle.up")
                .frame(width: 30, height: 40)
            }
            .disabled(row.fixedVolume == 128)
            .buttonRepeatBehavior(.enabled)
          }
          .frame(maxWidth: .infinity)

          Button {
            store.send(.autoConnectToggleTapped(row.id))
          } label: {
            Image(systemName: row.autoConnect ? "checkmark.circle.fill" : "circle")
              .frame(width: 40, height: 40)
          }
          .frame(maxWidth: .infinity)
        }
      }
    }
    .padding([.leading, .trailing], 16.0)
    .navigationTitle(Text("Connections"))
    .task {
      await store.send(.initialize).finish()
    }
    .onReceive(MIDITrafficIndicatorFeature.midiTrafficPublisher) { traffic in
      store.send(.sawMIDITraffic(traffic))
      withAnimation(.smooth(duration: 0.5)) {
        animating = traffic.id
        DispatchQueue.main.asyncAfter(deadline: .now() + 0.25) {
          withAnimation(.smooth(duration: 0.25)) {
            animating = nil
          }
        }
      }
    }
  }
}
