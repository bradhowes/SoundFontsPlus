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
  let log = Logger(category: "SoundFontButton")

  /**
   Attributes that affect the "accessory" button.
   */
  public struct StatusInfo {
    let action: Action
    let imageName: String
    let color: Color
  }

  public enum StatusInfoTag: Equatable, Sendable {
    case internalFile
    case invalidBookmark
    case localIsAvailable
    case localIsMissing
    case cloudIsDownloaded
    case cloudIsMissing

    static func value(for bookmark: Bookmark?) -> Self {
      guard let bookmark else {
        return .invalidBookmark
      }
      let cloudState = bookmark.cloudState
      if cloudState == .local {
        return bookmark.isAvailable ? .localIsAvailable : .localIsMissing
      } else {
        return cloudState == .downloaded ? .cloudIsDownloaded : .cloudIsMissing
      }
    }

    var statusInfo: StatusInfo {
      switch self {
      case .internalFile:
        return .init(action: .buttonTapped, imageName: "circle.fill", color: .black)
      case .invalidBookmark:
        return .init(action: .invalidBookmarkButtonTapped, imageName: "exclamationmark.circle", color: .red)
      case .localIsAvailable:
        return .init(action: .buttonTapped, imageName: "link", color: .accentColor)
      case .localIsMissing:
        return .init(action: .missingFileButtonTapped, imageName: "exclamationmark.circle", color: .yellow)
      case .cloudIsDownloaded:
        return .init(action: .buttonTapped, imageName: "icloud", color: .accentColor)
      case .cloudIsMissing:
        return .init(action: .downloadFileButtonTapped, imageName: "icloud.and.arrow.down", color: .yellow)
      }
    }
  }

  @ObservableState
  public struct State: Equatable, Identifiable {

    public var id: SoundFont.ID { soundFontInfo.id }
    public let soundFontInfo: SoundFontInfo
    public var statusInfoTag: StatusInfoTag

    public init(
      soundFontInfo: SoundFontInfo,
    ) {
      self.soundFontInfo = soundFontInfo
      self.statusInfoTag = Self.statusInfoTag(for: soundFontInfo)
    }

    static public func statusInfoTag(for soundFontInfo: SoundFontInfo) -> StatusInfoTag {
      soundFontInfo.kind == .external
      ? StatusInfoTag.value(for: try? Bookmark.from(data: soundFontInfo.location))
      : .internalFile
    }
  }

  public enum Action: Equatable {
    case bookmarkMonitorStart
    case bookmarkMonitorStop
    case buttonTapped
    case delegate(Delegate)
    case deleteButtonTapped
    case downloadFileButtonTapped
    case editButtonTapped
    case invalidBookmarkButtonTapped
    case longPressGestureFired
    case missingFileButtonTapped
    case statusInfoChanged(StatusInfoTag)

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
    case selectSoundFont(SoundFontInfo)
  }

  public init() {}

  public var body: some ReducerOf<Self> {
    Reduce<State, Action> { state, action in
      switch action {

      case .bookmarkMonitorStart:
        return bookmarkMonitorStart(&state)

      case .bookmarkMonitorStop:
        return .cancel(id: CancelId.bookmarkMonitor)

      case .buttonTapped:
        return .send(.delegate(.selectSoundFont(state.soundFontInfo)))

      case .deleteButtonTapped:
        return .send(.delegate(.deleteSoundFont(state.soundFontInfo))).animation(.default)

      case .downloadFileButtonTapped:
        return downloadFile(&state)

      case .editButtonTapped:
        return .send(.delegate(.editSoundFont(state.soundFontInfo)))

      case .invalidBookmarkButtonTapped:
        return .send(.delegate(.alertInvalidBookmark(state.soundFontInfo)))

      case .longPressGestureFired:
        return .send(.delegate(.editSoundFont(state.soundFontInfo)))

      case .missingFileButtonTapped:
        return .send(.delegate(.alertMissingFile(state.soundFontInfo)))

      case .statusInfoChanged(let statusInfoTag):
        state.statusInfoTag = statusInfoTag
        return .none

      default:
        return .none
      }
    }
  }

  private enum CancelId {
    case bookmarkMonitor
  }
}

extension SoundFontButton {

  private func bookmarkMonitorStart(_ state: inout State) -> Effect<Action> {
    guard state.soundFontInfo.kind == .external else { return .none }
    @Dependency(\.continuousClock) var clock
    let soundFontInfo = state.soundFontInfo
    return .run { [_statusInfoTag = state.statusInfoTag] send in
      var statusInfoTag = _statusInfoTag
      while !Task.isCancelled {
        try await clock.sleep(for: .seconds(2))
        let newStatusInfoTag = State.statusInfoTag(for: soundFontInfo)
        if newStatusInfoTag != statusInfoTag {
          await send(.statusInfoChanged(newStatusInfoTag))
          statusInfoTag = newStatusInfoTag
        }
      }
    }.cancellable(id: CancelId.bookmarkMonitor)
  }

  private func downloadFile(_ state: inout State) -> Effect<Action> {
    guard let bookmark = try? Bookmark.from(data: state.soundFontInfo.location) else { return .none }
    bookmark.url.withSecurityScoping { url in
      try FileManager.default.startDownloadingUbiquitousItem(at: url)
    }
    return .none
  }
}

struct SoundFontButtonView: View {
  @Bindable private var store: StoreOf<SoundFontButton>
  @Shared(.activeState) private var activeState
  @Shared(.selectedSoundFontId) private var selectedSoundFontId
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
        store.send(.buttonTapped, animation: .default)
      } label: {
        Text(store.soundFontInfo.displayName)
          .font(.button)
          .indicator(state)
      }
      Spacer()
      statusIndicator
    }
    .listRowSeparator(.hidden)
    .swipeActions(edge: .leading, allowsFullSwipe: false) {
      Button {
        store.send(.editButtonTapped, animation: .default)
      } label: {
        Image(systemName: "pencil")
          .tint(.cyan)
      }
    }
    .swipeActions(edge: .trailing, allowsFullSwipe: false) {
      if !store.soundFontInfo.isBuiltin {
        Button {
          store.send(.deleteButtonTapped, animation: .default)
        } label: {
          Image(systemName: "trash")
            .tint(.red)
        }
      }
    }
    .simultaneousGesture(
      LongPressGesture(minimumDuration: 1.0)
        .onEnded { _ in store.send(.longPressGestureFired) }
    )
    .task {
      await store.send(.bookmarkMonitorStart).finish()
    }
  }
}

extension SoundFontButtonView {

  public var statusIndicator: some View {
    let statusInfo = store.statusInfoTag.statusInfo
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

extension SoundFontButtonView {
  static var preview: some View {
    // swiftlint:disable:next force_try
    let soundFontInfos = try! prepareDependencies {
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
        .listRowSeparator(.hidden)
        .listStyle(.plain)
      }
      List {
        SoundFontButtonView(store: Store(initialState: .init(soundFontInfo: soundFontInfos[0])) { SoundFontButton() })
        SoundFontButtonView(store: Store(initialState: .init(soundFontInfo: soundFontInfos[1])) { SoundFontButton() })
      }.listStyle(.grouped)
    }
  }
}

#Preview {
  SoundFontButtonView.preview
}
