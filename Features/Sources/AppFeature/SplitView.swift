import ComposableArchitecture
import Sharing
import SwiftUI

/**
 The orientation of the two views with a divider view between them
 */
public enum SplitViewOrientation: Equatable {
  case horizontal
  case vertical

  var horizontal: Bool { self == .horizontal }
  var vertical: Bool { self == .vertical }
}

/**
 The indication of the visible panes in a split view. The `primary` is the left or top view
 and `secondary` is the other one. There are aliases for `left`, `right`, `top`, and `bottom` and
 definitions for `none` and `both`. In the SptiView code, only `primary` and `secondary` are referenced.
 */
public struct SplitViewPanes: OptionSet, Sendable, Equatable {
  public let rawValue: Int

  public init(rawValue: Int) {
    self.rawValue = rawValue
  }

  public static let none = SplitViewPanes([])
  public static let primary = SplitViewPanes(rawValue: 1 << 0)
  public static let secondary = SplitViewPanes(rawValue: 1 << 1)
  public static let both = SplitViewPanes(rawValue: primary.rawValue | secondary.rawValue)

  public static let left = primary
  public static let right = secondary

  public static let top = primary
  public static let bottom = secondary

  public var primary: Bool { self.contains(.primary) }
  public var secondary: Bool { self.contains(.secondary) }
  public var both: Bool { primary && secondary }
}

/**
 Configurable parameters for a SplitView. They mostly affect drag movements and behavior.
 */
public struct SplitViewConstraints: Equatable {
  /// The minimum fraction that the primary view will be constrained within. A value of `nil` means unconstrained.
  let minPrimaryFraction: CGFloat
  /// The minimum fraction that the secondary view will be constrained within. A value of `nil` means unconstrained.
  let minSecondaryFraction: CGFloat
  /// Whether to hide a pane when dragging stops past a min fraction value
  let dragToHide: SplitViewPanes
  /// The visible span of the divider view. The actual hit area for touch events can be larger depending on the
  /// definition of the divider.
  let visibleSpan: CGFloat

  public init(
    minPrimaryFraction: CGFloat = 0.0,
    minSecondaryFraction: CGFloat = 0.0,
    dragToHide: SplitViewPanes = [],
    visibleSpan: CGFloat = 16.0
  ) {
    self.minPrimaryFraction = minPrimaryFraction
    self.minSecondaryFraction = minSecondaryFraction
    self.dragToHide = dragToHide
    self.visibleSpan = visibleSpan
  }
}

@Reducer
public struct SplitViewReducer {

  @ObservableState
  public struct State: Equatable {
    public let orientation: SplitViewOrientation
    public let constraints: SplitViewConstraints
    public var panesVisible: SplitViewPanes
    public var position: CGFloat

    // Drag-gesture state. I tried to move into a @GestureState struct but its lifetime was not long enough to be
    // useful.
    public var highlightSide: SplitViewPanes
    @ObservationStateIgnored public var initialPosition: CGFloat?
    @ObservationStateIgnored public var lastPosition: CGFloat = .zero

    public init(
      orientation: SplitViewOrientation,
      constraints: SplitViewConstraints = .init(),
      panesVisible: SplitViewPanes = .both,
      position: CGFloat = 0.5
    ) {
      self.orientation = orientation
      self.constraints = constraints
      self.panesVisible = panesVisible
      self.position = position
      self.highlightSide = []
    }
  }

  public enum Action: Equatable {
    case dragBegin(CGFloat)
    case dragMove(CGFloat, SplitViewPanes)
    case dragEnd(CGFloat, SplitViewPanes)
    case panesVisibilityChanged(SplitViewPanes)
  }

  public init() {}

  public var body: some ReducerOf<Self> {
    Reduce { state, action  in
      switch action {
      case let .dragBegin(span):
        state.lastPosition = state.position
        state.initialPosition = span * state.position
        return .none
      case let .dragMove(position, willHide):
        state.position = position
        state.highlightSide = willHide
        return .none
      case let .dragEnd(position, visible):
        state.initialPosition = nil
        state.highlightSide = []
        state.panesVisible = visible
        state.position = position
        return .none
      case .panesVisibilityChanged(let visible):
        state.panesVisible = visible
        return .none
      }
    }
  }
}

/**
 Custom view that manages `primary` and a `secondary` views or "panes" separated by a divider view. The divider
 recognizes drag gestures to change the size of the managed views. It also supports a double-tap
 gesture that will close/hide one of the views when allowed in the `constraints` settings.
 */
public struct SplitView<P, D, S>: View where P: View, D: View, S: View {
  @State private var store: StoreOf<SplitViewReducer>
  private let primaryContent: () -> P
  private let secondaryContent: () -> S
  private let dividerContent: () -> D

  private var orientation: SplitViewOrientation { store.orientation }
  private var constraints: SplitViewConstraints { store.constraints }
  private var panesVisible: SplitViewPanes { store.panesVisible }
  private var highlightSide: SplitViewPanes { store.highlightSide }

  public init(
    store: StoreOf<SplitViewReducer>,
    @ViewBuilder primary: @escaping ()-> P,
    @ViewBuilder divider: @escaping () -> D,
    @ViewBuilder secondary: @escaping () -> S
  ) {
    self.store = store
    self.primaryContent = primary
    self.secondaryContent = secondary
    self.dividerContent = divider
  }

  public var body: some View {
    let _ = Self._printChanges()
    GeometryReader { geometry in
      let size = geometry.size
      let width = size.width
      let height = size.height
      let span: CGFloat = orientation.horizontal ? width : height
      let handleSpan: CGFloat = constraints.visibleSpan
      let handleSpan2: CGFloat = handleSpan / 2
      let dividerPos = (store.position * span).clamped(to: 0...span)
      let primarySpan = dividerPos - handleSpan2
      let secondarySpan = span - primarySpan - handleSpan
      let primaryAndHandleSpan = primarySpan + handleSpan

      let primaryFrame: CGSize = orientation.horizontal
      ? .init(width: panesVisible.secondary ? primarySpan : span, height: height)
      : .init(width: width, height: panesVisible.secondary ? primarySpan : span)

      let primaryOffset: CGSize = orientation.horizontal
      ? .init(width: panesVisible.primary ? 0 : -primaryAndHandleSpan, height: 0)
      : .init(width: 0, height: panesVisible.primary ? 0 : -primaryAndHandleSpan)

      let secondaryFrame: CGSize = orientation.horizontal
      ? .init(width: panesVisible.primary ? secondarySpan : span, height: height)
      : .init(width: width, height: panesVisible.primary ? secondarySpan : span)

      let secondaryOffsetSpan = panesVisible.both ? primaryAndHandleSpan : (panesVisible.primary ? span + handleSpan: 0)
      let secondaryOffset: CGSize = orientation.horizontal
      ? .init(width: secondaryOffsetSpan, height: 0)
      : .init(width: 0, height: secondaryOffsetSpan)

      let dividerOffset = (panesVisible.both ? dividerPos : (panesVisible.primary ? span + handleSpan2 : -handleSpan2))
      let dividerPt: CGPoint = orientation.horizontal
      ? .init(x: dividerOffset, y: height / 2)
      : .init(x: width / 2, y: dividerOffset)

      ZStack(alignment: .topLeading) {
        primaryContent()
          .zIndex(panesVisible.primary ? 0 : -1)
          .frame(width: primaryFrame.width, height: primaryFrame.height)
          .blur(radius: highlightSide == .primary ? 3 : 0, opaque: false)
          .offset(primaryOffset)
          .allowsHitTesting(panesVisible.primary)

        secondaryContent()
          .zIndex(panesVisible.secondary ? 0 : -1)
          .frame(width: secondaryFrame.width, height: secondaryFrame.height)
          .blur(radius: highlightSide == .secondary ? 3 : 0, opaque: false)
          .offset(secondaryOffset)
          .allowsHitTesting(panesVisible.secondary)

        dividerContent()
          .position(dividerPt)
          .zIndex(panesVisible.both ? 1 : -1)
          .onTapGesture(count: 2) {
            if constraints.dragToHide.contains(.primary) {
              store.send(.panesVisibilityChanged(.secondary))
            } else if constraints.dragToHide.contains(.secondary) {
              store.send(.panesVisibilityChanged(.primary))
            }
          }
          .simultaneousGesture(
            drag(in: span, change: orientation.horizontal ? \.translation.width : \.translation.height)
          )
      }
      .frame(width: width, height: height)
      .clipped()
      .animation(.smooth, value: store.panesVisible)
    }
  }
}

extension SplitView {

  private func drag(in span: CGFloat, change: KeyPath<DragGesture.Value, CGFloat>) -> some Gesture {
    return DragGesture(coordinateSpace: .global)
      .onChanged { gesture in
        if let initialPosition = store.initialPosition {
          let unconstrained = (initialPosition + gesture[keyPath: change]).clamped(to: 0...span) / span
          let position = unconstrained.clamped(to: lowerBound...upperBound)
          if position < minPrimarySpan {
            store.send(.dragMove(position, .primary))
          } else if position > maxSecondarySpan {
            store.send(.dragMove(position, .secondary))
          } else {
            store.send(.dragMove(position, .none))
          }
        } else {
          store.send(.dragBegin(span))
        }
      }
      .onEnded { gesture in
        if store.position < minPrimarySpan {
          store.send(.dragEnd(store.lastPosition, .secondary))
        } else if store.position > maxSecondarySpan {
          store.send(.dragEnd(store.lastPosition, .primary))
        } else {
          store.send(.dragEnd(store.position.clamped(to: minPrimarySpan...maxSecondarySpan), .both))
        }
      }
  }

  private var minPrimarySpan: CGFloat { constraints.minPrimaryFraction }
  private var maxSecondarySpan: CGFloat { 1.0 - constraints.minSecondaryFraction }
  private var lowerBound: CGFloat { constraints.dragToHide.contains(.primary) ? 0.0 : minPrimarySpan }
  private var upperBound: CGFloat { constraints.dragToHide.contains(.secondary) ? 1.0 : maxSecondarySpan }
}

struct HandleDivider: View {
  let orientation: SplitViewOrientation
  let dividerConstraints: SplitViewConstraints
  let handleColor: Color
  let handleLength: CGFloat
  let paddingInsets: CGFloat

  init(
    for orientation: SplitViewOrientation,
    dividerConstraints: SplitViewConstraints,
    handleColor: Color = Color.indigo,
    handleLength: CGFloat = 24.0,
    paddingInsets: CGFloat = 6.0
  ) {
    self.orientation = orientation
    self.dividerConstraints = dividerConstraints
    self.handleColor = handleColor
    self.handleLength = 24
    self.paddingInsets = paddingInsets
  }

  var body: some View {
    ZStack {
      switch orientation {
      case .horizontal:

        Rectangle()
          .fill(Color(red: 0.08, green: 0.08, blue: 0.08))
          .frame(width: 10)
          .padding(0)

        RoundedRectangle(cornerRadius: dividerConstraints.visibleSpan / 2)
          .fill(handleColor)
          .frame(width: dividerConstraints.visibleSpan, height: handleLength)
          .padding(EdgeInsets(top: paddingInsets, leading: 0, bottom: paddingInsets, trailing: 0))

        VStack {
          Color.black
            .frame(width: 2, height: 2)
          Color.black
            .frame(width: 2, height: 2)
        }

      case .vertical:

        Rectangle()
          .fill(Color(red: 0.08, green: 0.08, blue: 0.08))
          .frame(height: 10)
          .padding(0)

        RoundedRectangle(cornerRadius: dividerConstraints.visibleSpan / 2)
          .fill(handleColor)
          .frame(width: handleLength, height: dividerConstraints.visibleSpan)
          .padding(EdgeInsets(top: 0, leading: paddingInsets, bottom: 0, trailing: paddingInsets))

        HStack {
          Color.black
            .frame(width: 2, height: 2)
          Color.black
            .frame(width: 2, height: 2)
        }
      }
    }
    .contentShape(Rectangle())
  }
}

public struct DebugDivider: View {
  private let orientation: SplitViewOrientation
  public let visibleSpan: CGFloat = 16
  public let invisibleSpan: CGFloat = 32
  public var horizontal: Bool { orientation.horizontal }
  public var vertical: Bool { orientation.vertical }

  init(for orientation: SplitViewOrientation) {
    self.orientation = orientation == .horizontal ? .vertical : .horizontal
  }

  public var body: some View {
    ZStack(alignment: .center) {
      Color.blue.opacity(0.50)
        .frame(width: horizontal ? nil : invisibleSpan, height: horizontal ? invisibleSpan : nil)
      Color.red.opacity(1.0)
        .frame(width: horizontal ? nil : visibleSpan, height: horizontal ? visibleSpan : nil)
    }
  }
}

private struct DemoHSplit: View {
  @State var store: StoreOf<SplitViewReducer>

  public init(store: StoreOf<SplitViewReducer>) {
    self.store = store
  }

  public var body: some View {
    SplitView(store: store) {
      VStack {
        Button(store.panesVisible.both ? "Hide Right" : "Show Right") {
          store.send(.panesVisibilityChanged(store.panesVisible.both ? .primary : .both))
        }
      }
      .frame(maxWidth: .infinity, maxHeight: .infinity)
      .background(Color.green)
    } divider: {
      DebugDivider(for: .horizontal)
    } secondary: {
      VStack {
        Button(store.panesVisible.both ? "Hide Left" : "Show Left") {
          store.send(.panesVisibilityChanged(store.panesVisible.both ? .secondary : .both))
        }
      }
      .frame(maxWidth: .infinity, maxHeight: .infinity)
      .background(Color.orange)
    }
  }
}

private struct DemoVSplit: View {
  @State var store: StoreOf<SplitViewReducer>
  let inner: StoreOf<SplitViewReducer>

  public var body: some View {
    VStack {
      SplitView(store: store) {
        VStack {
          Button(store.panesVisible.both ? "Hide Bottom" : "Show Bottom") {
            store.send(.panesVisibilityChanged(store.panesVisible.both ? .primary : .both))
          }
        }
        .frame(maxWidth: .infinity, maxHeight: .infinity)
        .background(Color.mint)
      } divider: {
        DebugDivider(for: .vertical)
      } secondary: {
        HStack {
          VStack {
            Button(store.panesVisible.both ? "Hide Top" : "Show Top") {
              store.send(.panesVisibilityChanged(store.panesVisible.both ? .secondary : .both))
            }
          }.contentShape(Rectangle())
          DemoHSplit(store: inner)
        }
        .frame(maxWidth: .infinity, maxHeight: .infinity)
        .background(Color.teal)
      }
      HStack {
        Button {
          store.send(.panesVisibilityChanged(store.panesVisible.both ? .secondary : .both))
        } label: {
          Text("Top")
            .foregroundStyle(store.panesVisible.primary ? Color.orange : Color.accentColor)
            .animation(.smooth, value: store.panesVisible)
        }
        Button {
          store.send(.panesVisibilityChanged(store.panesVisible.both ? .primary : .both))
        } label: {
          Text("Bottom")
            .foregroundStyle(store.panesVisible.secondary ? Color.orange : Color.accentColor)
            .animation(.smooth, value: store.panesVisible)
        }
        Button {
          inner.send(.panesVisibilityChanged(inner.panesVisible.both ? .secondary : .both))
        } label: {
          Text("Left")
            .foregroundStyle(inner.panesVisible.primary ? Color.orange : Color.accentColor)
            .animation(.smooth, value: store.panesVisible)
        }
        Button {
          inner.send(.panesVisibilityChanged(inner.panesVisible.both ? .primary : .both))
        } label: {
          Text("Right")
            .foregroundStyle(inner.panesVisible.secondary ? Color.orange : Color.accentColor)
            .animation(.smooth, value: store.panesVisible)
        }
      }
    }
  }
}

struct SplitView_Previews: PreviewProvider {
  static var previews: some View {
    DemoVSplit(
      store: Store(initialState: .init(
        orientation: .vertical,
        constraints: .init(
          minPrimaryFraction: 0.2,
          minSecondaryFraction: 0.2,
          dragToHide: .secondary,
          visibleSpan: 16.0
        )
      )) { SplitViewReducer() },
      inner: Store(initialState: .init(
        orientation: .horizontal,
        constraints: .init(
          minPrimaryFraction: 0.3,
          minSecondaryFraction: 0.3,
          dragToHide: .both,
          visibleSpan: 16.0
        )
      )) { SplitViewReducer() }
    )
  }
}

private extension Comparable {
  func clamped(to limits: ClosedRange<Self>) -> Self { min(max(self, limits.lowerBound), limits.upperBound) }
}

private extension ClosedRange {
  func clamp(value : Bound) -> Bound { value.clamped(to: self) }
}
