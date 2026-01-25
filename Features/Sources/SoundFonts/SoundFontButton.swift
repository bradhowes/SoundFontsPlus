// Copyright © 2025 Brad Howes. All rights reserved.

import Clocks
import Dependencies
import FeatureSupport

/**
 Feature that handles activity for SoundFont buttons shown in the list of fonts. Provides a visual indication of
 the availability of the font file when the file exist in an iCloud folder or on an external device.
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
    case deleteSoundFont(SoundFontInfo)
    case editSoundFont(SoundFontInfo)
    case selectSoundFont(SoundFontInfo, available: Bool)
  }

  public init() {}

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
        state.deleting = false
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

  private func bookmarkMonitorStart(_ state: inout State) -> Effect<Action> {
    guard state.soundFontInfo.kind == .external else { return .none }
    @Dependency(\.continuousClock) var clock
    return .run(
      priority: .utility,
      name: "bookmarkMonitor"
    ) { [currentStatusInfoTag = state.statusInfoTag, soundFontInfo = state.soundFontInfo] send in
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
  @Shared(.selectedSoundFontId) private var selectedSoundFontId
  @Shared(.activeState) private var activeState
  @Environment(\.editMode) private var deletingMode
  private var inDeletingMode: Bool { (deletingMode?.wrappedValue ?? .inactive) == .active }
  private var canDelete: Bool { inDeletingMode && store.soundFontInfo.kind != .builtin }
  private var state: IndicatorModifier.State {
    activeState.activeSoundFontId == store.state.soundFontInfo.id ? .active :
    selectedSoundFontId == store.state.soundFontInfo.id ? .selected : .none
  }

  public init(store: StoreOf<SoundFontButton>) {
    self.store = store
  }

  public var body: some View {
    HStack {
      Button {
        if inDeletingMode {
          store.send(.toggleDeleting)
        } else {
          store.send(.delegate(.selectSoundFont(store.soundFontInfo, available: store.statusInfoTag.available)), animation: .default)
        }
      } label: {
        HStack {
          Image(systemName: store.deleting ? "inset.filled.circle" : "circle")
            .foregroundStyle(Color.red)
            .frame(width: canDelete ? 24 : 0)
            .opacity(canDelete ? 1.0 : 0.0)
            .disabled(!canDelete)
            .animation(.smooth, value: store.deleting) // animate the visibiliity toggle image
          Text(store.soundFontInfo.displayName)
            .font(.button)
            .indicator(inDeletingMode ? .none : state)
          Spacer() // Have the stack take up the whole region of the list so that touch hits will happen anywhere on the item
        }
        .contentShape(.interaction, Rectangle())
        .simultaneousGesture(
          LongPressGesture(minimumDuration: 1.0)
            .onEnded { _ in store.send(.delegate(.editSoundFont(store.soundFontInfo))) }
        )
        .animation(.smooth, value: inDeletingMode) // animate the transition to/from visibility editing
        .onChange(of: inDeletingMode) {
          if inDeletingMode && store.deleting {
            store.send(.resetDeleting)
          }
        }
      }
      Spacer()
      statusIndicator
    }
    .swipeActions(edge: .leading, allowsFullSwipe: false) {
      Button {
        store.send(.delegate(.editSoundFont(store.soundFontInfo)), animation: .default)
      } label: {
        Image(systemName: "pencil")
          .tint(.cyan)
      }
    }
    .swipeActions(edge: .trailing, allowsFullSwipe: false) {
      if !store.soundFontInfo.isBuiltin {
        Button {
          store.send(.delegate(.deleteSoundFont(store.soundFontInfo)), animation: .default)
        } label: {
          Image(systemName: "trash")
            .tint(.red)
        }
      }
    }
    .task {
      await store.send(.bookmarkMonitorStart).finish()
    }
  }
}

extension SoundFontButtonView {

  public var statusIndicator: some View {
    let statusInfo = store.statusInfoTag.statusInfo(store.soundFontInfo)
    let isDisabled = store.statusInfoTag == .internalFile

    return Button {
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
    // swiftlint:disable:next force_try
    let soundFontInfos = try! prepareDependencies {
      @Shared(.hideBuiltinFonts) var hideBuiltinFonts = false
      @Shared(.hideEmptyTags) var hideEmptyTags = false
      $0.defaultDatabase = previewDatabase()
      return try $0.defaultDatabase.read { db in
        try SoundFontInfo.query().fetchAll(db)
      }
    }

    @Shared(.activeState) var activeState
    $activeState.withLock { $0.activeSoundFontId = soundFontInfos[0].id }
    @Shared(.selectedSoundFontId) var selectedSoundFontId
    $selectedSoundFontId.withLock { $0 = soundFontInfos[1].id }

    return VStack {
      Section {
        List {
          SoundFontButtonView(store: Store(initialState: .init(soundFontInfo: soundFontInfos[0])) { SoundFontButton() })
          SoundFontButtonView(store: Store(initialState: .init(soundFontInfo: soundFontInfos[1])) { SoundFontButton() })
        }
      }
      List {
        SoundFontButtonView(store: Store(initialState: .init(soundFontInfo: soundFontInfos[0])) { SoundFontButton() })
        SoundFontButtonView(store: Store(initialState: .init(soundFontInfo: soundFontInfos[1])) { SoundFontButton() })
      }
#if os(iOS)
      .listStyle(.grouped)
#endif
    }
  }
}

#Preview {
  SoundFontButtonView.preview
}

#endif
