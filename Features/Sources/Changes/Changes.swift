// Copyright © 2025 Brad Howes. All rights reserved.

import FeatureSupport

/**
 Presents the list of changes for the app.
 */
@Reducer
public struct Changes {

  /**
   Representation of a versioned change log.
   */
  public struct Change: Hashable {
    /// The semantic version of the change
    public let version: String
    /// The collection of changes, presented as a bullet list
    public let items: [String]

    public init(version: String, items: [String]) {
      self.version = version
      self.items = items
    }
  }

  @ObservableState
  public struct State: Equatable {
    public let log: [Change]

    public init(_ data: String) {
      self.log = Changes.compile(data)
    }
  }

  public enum Action {
    case dismissButtonTapped
  }

  public init() {}

  public var body: some ReducerOf<Self> {

    Reduce { _, action in
      switch action {

      case .dismissButtonTapped:
        @Dependency(\.dismiss) var dismiss
        return .run { _ in await dismiss() }
      }
    }
  }

  /// - returns: True if the app should show the changes made per version.
  public static var shouldShow: Bool {
    @Shared(.lastShowedChangesVersion) var lastShowedChangesVersion
    defer { $lastShowedChangesVersion.withLock { $0 = Bundle.main.releaseVersionNumber } }
    // Only show when the version has changed and this is not an initial install
    return lastShowedChangesVersion != Bundle.main.releaseVersionNumber && !lastShowedChangesVersion.isEmpty
  }

  /**
   Convert string content into a list of ``Change`` values.

   - parameter data: the content to process
   - returns: array of ``Change`` values
   */
  public static func compile(_ data: String) -> [Change] {
    var entries = [Change]()
    var version = ""
    var items = [String]()

    for line in data.components(separatedBy: .newlines) {
      if line.hasPrefix("# ") {
        if !version.isEmpty && !items.isEmpty {
          entries.append(.init(version: version, items: items))
        }
        version = String(line[line.index(line.startIndex, offsetBy: 2)...]).trimmedOfWhitespaces
        items = []
      } else if line.hasPrefix("* ") {
        let item = String(line[line.index(line.startIndex, offsetBy: 2)...]).trimmedOfWhitespaces
        items.append(item)
      } else if line.hasPrefix(" ") && !items.isEmpty {
        items[items.count - 1] = (items.last ?? "") + " " + line.trimmedOfWhitespaces
      }
    }

    if !version.isEmpty && !items.isEmpty {
      entries.append(.init(version: version, items: items))
    }

    return entries
  }
}

public struct ChangesView: View {
  private var store: StoreOf<Changes>

  public init(store: StoreOf<Changes>) {
    self.store = store
  }

  public var body: some View {
    ScrollView {
      Text("Changes")
        .font(.navigationTitle)
        .foregroundStyle(Color.mainAccentColor)
      Grid(alignment: .leading, verticalSpacing: 8) {
        ForEach(store.log, id: \.self) { change in
          Text(change.version)
            .font(.changeVersion)
            .foregroundStyle(Color.alternateAccentColor)
            .gridColumnAlignment(.leading)
            .padding([.top], 18)
          ForEach(change.items, id: \.self) { item in
            GridRow {
              Text("•")
                .font(.changeVersion)
                .foregroundStyle(Color.alternateAccentColor)
              Text(item)
                .gridColumnAlignment(.leading)
                .font(.changeDescription)
                .foregroundStyle(Color.mainAccentColor)
            }
          }
        }
      }
      .padding([.leading, .trailing], 24)
    }
    .padding([.bottom], 24)
    .navigationTitle("")
    .toolbar {
      ToolbarItem(placement: .automatic) {
        Button {
          store.send(.dismissButtonTapped, animation: .default)
        } label: {
          Image(systemName: .checkmarkImageName)
        }
      }
    }
  }
}

extension View {

  public func changesSheet(_ store: Binding<StoreOf<Changes>?>) -> some View {
    self
      .sheet(item: store) { child in
        NavigationStack {
          ChangesView(store: child)
        }
      }
  }
}

#if DEBUG

extension ChangesView {
  static let previewData = """
      # 1.0.0
      * First item
      * Second
        item
      * Third
        long
        item
      * Fourth item that just goes on, and on
      # 1.1.0
      * Fixed first item
      * Removed second item
      """
  static var preview: some View {
    NavigationStack {
      ChangesView(store: .init(initialState: .init(previewData)) { Changes() })
    }
  }
}

#Preview {
  @Previewable @State var show: Bool = false
  VStack {
    Text("This is a test")
    Button {
      show = true
    } label: {
      Text("Show")
    }
  }
  .sheet(isPresented: $show) {
    ChangesView.preview
  }
}

#endif // DEBUG
