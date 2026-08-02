// Copyright © 2025 Brad Howes. All rights reserved.

public import CasePaths
import Clocks
public import ComposableArchitecture
import Dependencies
import FeatureSupport
public import Models
import SQLiteData
import SwiftUI
public import Tagged

/**
 Feature that handles activity for SoundFont buttons shown in the list of fonts.

 Provides a dynamic visual indication of the availability of the font file when the file exist in an iCloud folder or on an
 external device.
 */
@Reducer
public struct SoundFontButton {

  @ObservableState
  public struct State: Equatable, Identifiable {

    public var id: SoundFont.ID { soundFontInfo.id }
    public let bookmarkMonitorTaskId: String
    public let soundFontInfo: SoundFontInfo
    public var statusInfoTag: SoundFontButtonStatusInfoTag
    public var deleting: Bool

    public init(
      soundFontInfo: SoundFontInfo
    ) {
      self.soundFontInfo = soundFontInfo
      self.bookmarkMonitorTaskId = "SoundFontButton.\(soundFontInfo.id).bookMarkMonitorTaskId"
      self.statusInfoTag = Self.statusInfoTag(for: soundFontInfo)
      self.deleting = false
    }

    static public func statusInfoTag(for soundFontInfo: SoundFontInfo) -> SoundFontButtonStatusInfoTag {
      soundFontInfo.kind == .external
      ? SoundFontButtonStatusInfoTag.value(for: try? Bookmark.from(data: soundFontInfo.location))
      : .internalFile
    }
  }

  public enum Action {
    case bookmarkMonitorStart
    case bookmarkMonitorStop
    case delegate(Delegate)
    case downloadFileButtonTapped
    case resetDeleting
    case statusInfoChanged(SoundFontButtonStatusInfoTag)
    case toggleDeleting

    @CasePathable
    public enum ConfirmationDialog {
      case cancelButtonTapped
      case deleteButtonTapped
    }
  }

  @CasePathable
  public enum Delegate: Equatable {
    case alertInvalidBookmark(SoundFontInfo)
    case alertMissingFile(SoundFontInfo)
    case delete(SoundFontInfo)
    case edit(SoundFontInfo)
    case select(SoundFontInfo, available: Bool)
  }

  public init() {}

  @Dependency(\.continuousClock) var clock

  public var body: some ReducerOf<Self> {
    Reduce<State, Action> { state, action in
      switch action {

      case .bookmarkMonitorStart:
        return bookmarkMonitorStart(&state)

      case .bookmarkMonitorStop:
        return .cancel(id: state.bookmarkMonitorTaskId)

      case .delegate:
        return .none

      case .downloadFileButtonTapped:
        return downloadFile(&state)

      case .resetDeleting:
        Self.resetDeleting(&state)
        return .none

      case .statusInfoChanged(let statusInfoTag):
        state.statusInfoTag = statusInfoTag
        return .none

      case .toggleDeleting:
        state.deleting.toggle()
        return .none
      }
    }
  }
}

extension SoundFontButton {

  static public func resetDeleting(_ state: inout State) {
    state.deleting = false
  }

  private func bookmarkMonitorStart(_ state: inout State) -> Effect<Action> {
    guard state.soundFontInfo.kind == .external else { return .none }
    return .run(
      priority: .utility,
      name: "bookmarkMonitor"
    ) { [currentStatusInfoTag = state.statusInfoTag, soundFontInfo = state.soundFontInfo, clock] send in
      var statusInfoTag = currentStatusInfoTag
      while !Task.isCancelled {
        try await clock.sleep(for: .seconds(2))
        let newStatusInfoTag = State.statusInfoTag(for: soundFontInfo)
        if newStatusInfoTag != statusInfoTag {
          await send(.statusInfoChanged(newStatusInfoTag))
          statusInfoTag = newStatusInfoTag
        }
      }
    }.cancellable(id: state.bookmarkMonitorTaskId)
  }

  private func downloadFile(_ state: inout State) -> Effect<Action> {
    guard let bookmark = try? Bookmark.from(data: state.soundFontInfo.location) else { return .none }
    state.statusInfoTag = .cloudIsDownloading
    bookmark.url.withSecurityScoping { url in
      try FileManager.default.startDownloadingUbiquitousItem(at: url)
    }
    return .none
  }
}

// MARK: - View

struct SoundFontButtonView: View {
  private var store: StoreOf<SoundFontButton>
  @Environment(\.editMode) private var deletingMode
  private var inDeletingMode: Bool { (deletingMode?.wrappedValue ?? .inactive) == .active }
  private var canDelete: Bool { store.soundFontInfo.kind != .builtin }
  private let indicatorModifierState: IndicatorModifier.State

  public init(store: StoreOf<SoundFontButton>, indicatorModifierState: IndicatorModifier.State) {
    self.store = store
    self.indicatorModifierState = indicatorModifierState
  }

  public var body: some View {
    Button {
      store.send(
        inDeletingMode
        ? .toggleDeleting
        : .delegate(.select(store.soundFontInfo, available: store.statusInfoTag.available)),
        animation: .default
      )
    } label: {
      HStack {
        if inDeletingMode && canDelete {
          Image(systemName: store.deleting ? "inset.filled.circle" : "circle")
            .foregroundStyle(Color.red)
            .frame(width: 24)
            .animation(.smooth, value: store.deleting)
        }
        Text(store.soundFontInfo.displayName)
          .font(.button)
        Spacer()
        StatusIndicator(
          store: store,
          statusInfo: store.statusInfoTag.statusInfo(store.soundFontInfo),
          isDisabled: store.statusInfoTag == .internalFile
        )
      }
      .indicator(inDeletingMode ? .none : indicatorModifierState)
      .contentShape(.interaction, Rectangle())
      .simultaneousGesture(
        LongPressGesture(minimumDuration: 1.0)
          .onEnded { _ in store.send(.delegate(.edit(store.soundFontInfo))) }
      )
      .animation(.smooth, value: inDeletingMode) // animate the transition to/from visibility editing
      .onChange(of: inDeletingMode) {
        if inDeletingMode && store.deleting {
          store.send(.resetDeleting)
        }
      }
    }
    .swipeActions(edge: .leading, allowsFullSwipe: false) {
      Button {
        store.send(.delegate(.edit(store.soundFontInfo)), animation: .default)
      } label: {
        Image(systemName: .editButtonImageName)
          .tint(.cyan)
      }
    }
    .swipeActions(edge: .trailing, allowsFullSwipe: false) {
      if canDelete {
        Button {
          store.send(.delegate(.delete(store.soundFontInfo)), animation: .default)
        } label: {
          Image(systemName: .deleteButtonImageName)
            .tint(.red)
        }
      }
    }
    .task {
      await store.send(.bookmarkMonitorStart).finish()
    }
  }
}

private struct StatusIndicator: View {
  private let store: StoreOf<SoundFontButton>
  private let statusInfo: SoundFontButtonStatusInfo
  private let isDisabled: Bool

  init(store: StoreOf<SoundFontButton>, statusInfo: SoundFontButtonStatusInfo, isDisabled: Bool) {
    self.store = store
    self.statusInfo = statusInfo
    self.isDisabled = isDisabled
  }

  var body: some View {
    Button {
      store.send(statusInfo.action)
    } label: {
      Image(systemName: statusInfo.imageName)
        .foregroundColor(statusInfo.color)
        .frame(width: 25, height: 25)
    }
    .opacity(isDisabled ? 0.0 : 1.0)
    .disabled(isDisabled)
  }
}

private let log: Logger = .init(category: "SoundFontButton")

#if DEBUG

extension SoundFontButtonView {
  static var preview: some View {
    let soundFontInfos = withDatabaseReader {
      try SoundFontInfo.query(for: Tag.Ubiquitous.all.id).fetchAll($0)
    } ?? []
    return VStack {
      Section {
        List {
          SoundFontButtonView(
            store: Store(initialState: .init(soundFontInfo: soundFontInfos[0])) { SoundFontButton()
            },
            indicatorModifierState: .active)
          SoundFontButtonView(
            store: Store(initialState: .init(soundFontInfo: soundFontInfos[1])) { SoundFontButton()
            },
            indicatorModifierState: .selected)
        }
      }
      List {
        SoundFontButtonView(
          store: Store(initialState: .init(soundFontInfo: soundFontInfos[0])) { SoundFontButton()
          },
          indicatorModifierState: .active)
        SoundFontButtonView(
          store: Store(initialState: .init(soundFontInfo: soundFontInfos[1])) { SoundFontButton()
          },
          indicatorModifierState: .selected)
      }
#if os(iOS)
      .listStyle(.grouped)
#endif
    }
  }
}

#Preview {
  // swiftlint:disable:next redundant_discardable_let
  let _ = prepareDependencies {
    $0.defaultDatabase = previewDatabase()
  }
  SoundFontButtonView.preview
    .environment(\.font, Font.body)
}

#endif
