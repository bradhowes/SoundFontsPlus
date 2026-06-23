// Copyright © 2025 Brad Howes. All rights reserved.

import AVFAudio.AVAudioUnitSampler
import CoreMIDI
import FeatureSupport
import MIDITrafficIndicator
@preconcurrency @unsafe import MorkAndMIDI

/**
 Manages MIDI connections between external devices and the MIDI input port for the app.
 */
@Reducer
public struct MIDIConnections {

  @ObservableState
  public struct State: Equatable {
    public var rows: IdentifiedArrayOf<MIDIConnectionRow>
    public var midiTrafficIndicator: MIDITrafficIndicator.State = .init(tag: "MIDI Connections")
    @ObservationStateIgnored
    public var midiChannelsCache: [MIDIUniqueID: UInt8] = [:]

    public init(rows: [MIDIConnectionRow] = []) {
      self.rows = .init(uniqueElements: rows)
    }

    public func makeRows(from sourceConnections: [MIDI.SourceConnectionState]) -> IdentifiedArrayOf<MIDIConnectionRow> {
      log.info("makeRows: \(sourceConnections.count)")
      return .init(
        uniqueElements: sourceConnections.map { sourceConnection in
          let channel = midiChannelsCache[sourceConnection.uniqueId] ?? MIDIConnectionRow.unknownChannel
          log.info("row: \(String(describing: sourceConnection), privacy: .public), \(channel)")
          return MIDIConnectionRow(
            id: sourceConnection.uniqueId,
            displayName: sourceConnection.displayName,
            channel: channel,
            connected: sourceConnection.connected
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
    case midiConnectionsChanged
    case midiTrafficIndicator(MIDITrafficIndicator.Action)
    case sawMIDITraffic(MIDITrafficStat)
    case toggleConnected(MIDIUniqueID)
  }

  public init() {}

  @Dependency(\.midiProvider) var midiProvider
  @Shared(.midiMonitor) var midiMonitor

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
        return .merge(CancelId.allCases.map { .cancel(id: $0) })

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
        return .merge(
          .send(.midiTrafficIndicator(.initialize)),
          monitorMIDIConnections(&state)
        )

      case .midiConnectionsChanged:
        return updateMIDIConnections(&state)

      case .midiTrafficIndicator:
        return .none

      case .sawMIDITraffic(let traffic):
        return updateMIDIChannel(&state, traffic: traffic)

      case .toggleConnected(let id):
        return toggleConnected(&state, id: id)
      }
    }
  }

  private enum CancelId: String, CaseIterable {
    case midiConnectionsMonitorMIDIConnections
  }
}

extension MIDIConnections {

  private func monitorMIDIConnections(_ state: inout State) -> Effect<Action> {
    guard let midiMonitor else { return .none }

    // NOTE: the view expects the publisher to fire once after starting in order to fill the rows. If this is not guaranteed then
    // add a call to updateMIDIConnections()
    return .run { send in
      for await _ in midiMonitor.$connectivity.values {
        await send(.midiConnectionsChanged)
      }
    }.cancellable(id: CancelId.midiConnectionsMonitorMIDIConnections)
  }

  private func toggleConnected(_ state: inout State, id: MIDIUniqueID) -> Effect<Action> {
    guard let midi = midiProvider.midi() else { return .none }
    if let index = state.rows.index(id: id) {
      if state.rows[index].connected {
        state.rows[index].connected = false
        midi.disconnect(from: id)
      } else {
        state.rows[index].connected = midi.connect(to: id, unchecked: true)
      }
    }
    return .none
  }

  private func updateMIDIChannel(_ state: inout State, traffic: MIDITrafficStat) -> Effect<Action> {
    state.midiChannelsCache[traffic.id] = traffic.channel
    if let index = state.rows.index(id: traffic.id) {
      state.rows[index].channel = traffic.channel
    }
    return .none
  }

  private func updateMIDIConnections(_ state: inout State) -> Effect<Action> {
    // Hack to allow preview data to exist
    if let midi = midiProvider.midi() {
      state.rows = state.makeRows(from: midi.sourceConnections)
    }
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
    let columns = [
      GridItem(.flexible(minimum: 20, maximum: .infinity)),
      GridItem(.fixed(40)),
      GridItem(.fixed(120)),
      GridItem(.fixed(40)),
      GridItem(.fixed(40))
    ]
    return VStack {
      ScrollView {
        LazyVGrid(
          columns: columns,
          spacing: 0,
          pinnedViews: [.sectionHeaders]
        ) {
          Section {
            ForEach(store.rows) { row in
              rowContent(row)
            }
          } header: {
            LazyVGrid(columns: columns, spacing: 0) {
              Text("Name")
                .frame(maxWidth: .infinity)
                .font(.footnote)
                .foregroundStyle(.secondary)
              Text("Chan")
                .font(.footnote)
                .foregroundStyle(.gray)
              Text("Fixed Velocity")
                .font(.footnote)
                .foregroundStyle(.gray)
              Image(systemName: .midiDeviceAutoConnectImageName)
                .foregroundStyle(.gray)
              Image(systemName: .midiDeviceConnectedImageName)
                .foregroundStyle(.gray)
            }
            .padding([.top, .bottom], 4)
            .background(.background)
          }
        }
      }
      .padding([.leading, .trailing], 16.0)
      Text(
        """
        Chan — last reported MIDI channel of the device
        Fixed Velocity — velocity for note events from device
        \(Image(systemName: .midiDeviceAutoConnectImageName)) — auto-connect device when it appears
        \(Image(systemName: .midiDeviceConnectedImageName)) — current connection state (tap to change)
        """
      )
      .font(.footer)
      // .foregroundStyle(.gray)
    }
    .padding(16)
    .navigationTitle(Text("MIDI Connections"))
    .task {
      await store.send(.initialize).finish()
    }
    .onReceive(store.midiTrafficIndicator.midiTrafficPublisher) { traffic in
      store.send(.sawMIDITraffic(traffic))
      withAnimation(.smooth(duration: 0.5)) {
        animating = traffic.id
      } completion: {
        withAnimation(.smooth(duration: 0.25)) {
          animating = nil
        }
      }
    }
  }

  @ViewBuilder
  private func rowContent(_ row: MIDIConnectionRow) -> some View {
    Text("\(row.displayName)")
      .frame(maxWidth: .infinity, alignment: .leading)
      .foregroundStyle(animating == row.id ? Color.mainAccentColor : .primary)

    Text(row.channel == 255 ? "-" : "\(row.channel + 1)")
      .frame(maxWidth: .infinity)

    HStack(spacing: 0) {
      Text(row.fixedVolume == 128 ? "Off" : "\(row.fixedVolume)")
        .padding([.leading], 8)
      Button {
        store.send(.fixedVolumeDecrementTapped(row.id))
      } label: {
        Image(systemName: .arrowDownButtonImageName)
          .frame(width: 30, height: 40)
      }
      .disabled(row.fixedVolume == 1)
      .buttonRepeatBehavior(.enabled)

      Button {
        store.send(.fixedVolumeIncrementTapped(row.id))
      } label: {
        Image(systemName: .arrowUpButtonImageName)
          .frame(width: 30, height: 40)
      }
      .disabled(row.fixedVolume == 128)
      .buttonRepeatBehavior(.enabled)
    }
    .frame(maxWidth: .infinity)

    Button {
      store.send(.autoConnectToggleTapped(row.id))
    } label: {
      Image(systemName: row.autoConnect ? .circledCheckMarkOnImageName : .circledCheckMarkOffImageName)
        .frame(width: 40, height: 40)
    }
    .frame(maxWidth: .infinity)

    Button {
      store.send(.toggleConnected(row.id))
    } label: {
      Image(systemName: row.connected ? .midiDeviceConnectedButtonImageName : .midiDeviceDisconnectedButtonImageName)
        .frame(width: 40, height: 40)
    }
    .frame(maxWidth: .infinity)
  }
}

private let log: Logger = .init(category: "MIDIConnections")

#if DEBUG

extension MIDIConnectionsView {
  static var preview: some View {
    navigationBarTitleStyle()
    return VStack {
      MIDIConnectionsView(
        store: Store(
          initialState: .init(
            rows: [
              MIDIConnectionRow(
                id: 1,
                displayName: "No channel",
                channel: MIDIConnectionRow.unknownChannel,
                fixedVolume: MIDIConnectionRow.disabledFixedVolume,
                autoConnect: true
              ),
              MIDIConnectionRow(
                id: 2,
                displayName: "Channel 1",
                channel: 0,
                fixedVolume: 127,
                autoConnect: false
              ),
              MIDIConnectionRow(
                id: 3,
                displayName: "This is a really long name",
                channel: 1,
                fixedVolume: 126,
                autoConnect: true
              ),
              MIDIConnectionRow(
                id: 4,
                displayName: "Device 4",
                channel: 1,
                fixedVolume: 126,
                autoConnect: false
              ),
              MIDIConnectionRow(
                id: 5,
                displayName: "Device 5",
                channel: 1,
                fixedVolume: 126,
                autoConnect: true
              ),
              MIDIConnectionRow(
                id: 6,
                displayName: "Device 6",
                channel: 1,
                fixedVolume: 126,
                autoConnect: true
              ),
              MIDIConnectionRow(
                id: 7,
                displayName: "Device 7",
                channel: 1,
                fixedVolume: 126,
                autoConnect: true
              ),
              MIDIConnectionRow(
                id: 8,
                displayName: "Device 8",
                channel: 1,
                fixedVolume: 126,
                autoConnect: true
              ),
              MIDIConnectionRow(
                id: 9,
                displayName: "Device 9",
                channel: 1,
                fixedVolume: 126,
                autoConnect: true
              ),
              MIDIConnectionRow(
                id: 10,
                displayName: "Device 10",
                channel: 1,
                fixedVolume: 126,
                autoConnect: true
              ),
              MIDIConnectionRow(
                id: 11,
                displayName: "Device 11",
                channel: 1,
                fixedVolume: 126,
                autoConnect: true
              ),
              MIDIConnectionRow(
                id: 12,
                displayName: "Device 12",
                channel: 1,
                fixedVolume: 126,
                autoConnect: true
              ),
              MIDIConnectionRow(
                id: 13,
                displayName: "Device 13",
                channel: 1,
                fixedVolume: 126,
                autoConnect: true
              )
            ]
          )
        ) {
          MIDIConnections()
        }
      )
    }
  }
}

#Preview {
  // swiftlint:disable:next redundant_discardable_let
  let _ = prepareDependencies {
    $0.defaultDatabase = previewDatabase(fonts: [])
  }
  MIDIConnectionsView.preview
}

#endif // DEBUG
