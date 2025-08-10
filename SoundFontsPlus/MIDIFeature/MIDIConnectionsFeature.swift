// Copyright © 2025 Brad Howes. All rights reserved.

import ComposableArchitecture
import CoreMIDI
@preconcurrency import MorkAndMIDI
import SharingGRDB
import SwiftUI

@Reducer
struct MIDIConnectionRow {
  @ObservableState
  struct State: Identifiable, Equatable, Sendable {
    let id: MIDIUniqueID
    let displayName: String
    let channel: Int?
    var fixedVolume: Int
    var autoConnect: Bool

    init(id: MIDIUniqueID, displayName: String, channel: Int?) {
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
  }

  enum Action {
    case autoConnectTapped
    case decrementVolumeTapped
    case incrementVolumeTapped
  }

  var body: some ReducerOf<Self> {
    Reduce { state, action in
      switch action {
      case .autoConnectTapped:
        state.autoConnect.toggle()
        return saveConfig(state)
      case .decrementVolumeTapped:
        state.fixedVolume -= 1
        return saveConfig(state)
      case .incrementVolumeTapped:
        state.fixedVolume += 1
        return saveConfig(state)
      }
    }
  }

  private func saveConfig(_ state: State) -> Effect<Action> {
    @Dependency(\.defaultDatabase) var database
    withErrorReporting {
      try database.write { db in
        try MIDIConfig.upsert {
          .init(uniqueId: state.id, autoConnect: state.autoConnect, fixedVolume: state.fixedVolume)
        }.execute(db)
      }
    }
    return .none
  }
}

struct MIDIConnectionRowView: View {
  @Bindable var store: StoreOf<MIDIConnectionRow>

  var body: some View {
    Text("\(store.displayName)")
      .frame(maxWidth: .infinity)
    Text(store.channel?.description ?? "-")
    HStack(spacing: 0) {
      Text(store.fixedVolume == 128 ? "Off" : "\(store.fixedVolume)")
      Button {
        store.send(.decrementVolumeTapped)
      } label: {
        Image(systemName: "arrowtriangle.down")
          .frame(width: 40, height: 40)
      }
      .offset(x: 6)
      .disabled(store.fixedVolume == 1)
      .buttonRepeatBehavior(.enabled)
      Button {
        store.send(.incrementVolumeTapped)
      } label: {
        Image(systemName: "arrowtriangle.up")
          .frame(width: 40, height: 40)
      }
      .disabled(store.fixedVolume == 128)
      .buttonRepeatBehavior(.enabled)
    }
    .offset(x: 8)
    Button {
      store.send(.autoConnectTapped)
    } label: {
      Image(systemName: store.autoConnect ? "checkmark.circle.fill" : "circle")
        .frame(width: 40, height: 40)
    }
  }
}

@Reducer
public struct MIDIConnectionsFeature {

  @ObservableState
  public struct State: Equatable, Sendable {
    let midi: MIDI
    var sources: IdentifiedArrayOf<MIDIConnectionRow.State>

    public init(midi: MIDI) {
      self.midi = midi
      self.sources = .init(
        uniqueElements: midi.sourceConnections.map {
          .init(id: $0.uniqueId, displayName: $0.displayName, channel: nil)
        }
      )
    }
  }

  public enum Action: Equatable, Sendable {
    case connectionsChanged
    case initialize
  }

  public var body: some ReducerOf<Self> {
    Reduce { state, action in
      switch action {
      case .connectionsChanged: return updateMidiConnections(&state)
      case .initialize: return initialize(&state)
      }
    }
  }
}

private extension MIDIConnectionsFeature {

  func initialize(_ state: inout State) -> Effect<Action> {
    .run { [midi = state.midi] send in
      for await _ in midi.publisher(for: \.activeConnections)
        .buffer(size: 1, prefetch: .byRequest, whenFull: .dropOldest)
        .values {
        await send(.connectionsChanged)
      }
    }
  }

  func updateMidiConnections(_ state: inout State) -> Effect<Action> {
    state.sources = .init(
      uniqueElements: state.midi.sourceConnections.map {
        .init(id: $0.uniqueId, displayName: $0.displayName, channel: nil)
      }
    )
    return .none
  }
}

public struct MIDIConnectionsView: View {
  private var store: StoreOf<MIDIConnectionsFeature>
  private let columns: [GridItem] = [
    .init(.flexible(minimum: 80, maximum: .infinity), alignment: .center),
    .init(.fixed(30), alignment: .center),
    .init(.fixed(120), alignment: .center),
    .init(.fixed(48), alignment: .center)
  ]

  public init(store: StoreOf<MIDIConnectionsFeature>) {
    self.store = store
  }

  public var body: some View {
    ScrollView {
      LazyVGrid(columns: columns, spacing: 0) {
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
        ForEach(store.sources) { item in
          MIDIConnectionRowView(store: Store(initialState: item) { MIDIConnectionRow() })
        }
      }
    }
    .padding([.leading, .trailing], 16.0)
    .navigationTitle(Text("Connections"))
    .task {
      await store.send(.initialize).finish()
    }
  }
}
