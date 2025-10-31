// Copyright © 2025 Brad Howes. All rights reserved.

import Combine
import CoreMIDI
import FeatureSupport
import MIDITrafficIndicator
@preconcurrency @unsafe import MorkAndMIDI

@Reducer
public struct MIDIConnections {

  @ObservableState
  public struct State: Equatable {
    public var rows: IdentifiedArrayOf<MIDIConnectionRow>
    public var midiTrafficIndicator: MIDITrafficIndicator.State = .init(tag: "MIDI Connections")
    @ObservationStateIgnored
    public var midiChannelsCache: [MIDIUniqueID: UInt8] = [:]

    public init() {
      self.rows = .init()
      @Shared(.midi) var midi
      if let midi {
        self.rows = makeRows(from: midi.sourceConnections)
      }
    }

    public init(rows: [MIDIConnectionRow]) {
      self.rows = .init(uniqueElements: rows)
    }

    public func makeRows(
      from sourceConnections: [MIDI.SourceConnectionState]
    ) -> IdentifiedArrayOf<MIDIConnectionRow> {
      @Shared(.midiAutoConnect) var midiAutoConnect
      return .init(
        uniqueElements: sourceConnections.map { sourceConnection in
          let channel = midiChannelsCache[sourceConnection.uniqueId] ?? MIDIConnectionRow.unknownChannel
          return MIDIConnectionRow(
            id: sourceConnection.uniqueId,
            displayName: sourceConnection.displayName,
            channel: channel,
            fixedVolume: MIDIConnectionRow.disabledFixedVolume,
            autoConnect: midiAutoConnect
          )
        }
      )
    }
  }

  public enum Action {
    case autoConnectToggleTapped(MIDIUniqueID)
    case deinitialize
    case fixedVolumeDecrementTapped(MIDIUniqueID)
    case fixedVolumeIncrementTapped(MIDIUniqueID)
    case initialize
    case midiConnectionsChanged([MIDI.SourceConnectionState])
    case midiTrafficIndicator(MIDITrafficIndicator.Action)
    case sawMIDITraffic(MIDITraffic)
  }

  public init() {}

  @Shared(.midi) var midi

  public var body: some ReducerOf<Self> {

    Scope(state: \.midiTrafficIndicator, action: \.midiTrafficIndicator) { MIDITrafficIndicator() }

    Reduce { state, action in
      switch action {

      case .autoConnectToggleTapped(let id):
        if let index = state.rows.index(id: id) {
          state.rows[index].autoConnect.toggle()
          state.rows[index].save()
        }
        return .none

      case .deinitialize:
        return .merge(CancelId.allCases.map{ .cancel(id: $0) })

      case .fixedVolumeDecrementTapped(let id):
        if let index = state.rows.index(id: id) {
          state.rows[index].fixedVolume -= 1
          state.rows[index].save()
        }
        return .none

      case .fixedVolumeIncrementTapped(let id):
        if let index = state.rows.index(id: id) {
          state.rows[index].fixedVolume += 1
          state.rows[index].save()
        }
        return .none

      case .initialize:
        return initialize(&state)

      case .midiConnectionsChanged(let sourceConnections):
        return updateMidiConnections(&state, sourceConnections: sourceConnections)

      case .midiTrafficIndicator:
        return .none

      case .sawMIDITraffic(let traffic):
        return updateMIDIChannel(&state, traffic: traffic)
      }
    }
  }

  private enum CancelId: CaseIterable {
    case monitorMIDIConnections
  }
}

extension MIDIConnections {

  private func initialize(_ state: inout State) -> Effect<Action> {
    _ = updateMidiConnections(&state, sourceConnections: midi?.sourceConnections ?? [])
    return .merge(
      reduce(into: &state, action: .midiTrafficIndicator(.initialize)),
      monitorMIDIConnections(&state)
    )
  }

  private func monitorMIDIConnections(_ state: inout State) -> Effect<Action> {
    guard let midi else { return .none }
    return .publisher {
      midi.activeConnectionsPublisher
        .map { _ in .midiConnectionsChanged(midi.sourceConnections) }
    }.cancellable(id: CancelId.monitorMIDIConnections)
  }

  private func updateMIDIChannel(_ state: inout State, traffic: MIDITraffic) -> Effect<Action> {
    state.midiChannelsCache[traffic.id] = traffic.channel
    if let index = state.rows.index(id: traffic.id) {
      state.rows[index].channel = traffic.channel
    }
    return .none
  }

  private func updateMidiConnections(
    _ state: inout State,
    sourceConnections: [MIDI.SourceConnectionState]
  ) -> Effect<Action> {
    state.rows = state.makeRows(from: sourceConnections)
    return .none
  }
}

public struct MIDIConnectionsView: View {
  private var store: StoreOf<MIDIConnections>
  @State private var animating: MIDIUniqueID?

  public init(store: StoreOf<MIDIConnections>) {
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
    .navigationTitle(Text("MIDI Connections"))
    .task {
      await store.send(.initialize).finish()
    }
    .onReceive(store.midiTrafficIndicator.midiTrafficPublisher) { traffic in
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

extension MIDIConnectionsView {
  static var preview: some View {
    prepareDependencies {
      @Shared(.midi) var midi = MIDI(clientName: "Test", uniqueId: 123, midiProto: .v1_0)
      midi?.start()
      // swiftlint:disable:next force_try
      $0.defaultDatabase = try! appDatabase(addBuiltInFonts: false)
    }
    navigationBarTitleStyle()
    return VStack {
      MIDIConnectionsView(
        store: Store(initialState: .init()) {
          MIDIConnections()
        }
      )
    }
  }
}

#Preview {
  MIDIConnectionsView.preview
}
