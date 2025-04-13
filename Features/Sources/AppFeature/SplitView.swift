import SwiftUI

/**
 The orientation of the two views with a divider view between them
 */
public enum SplitViewOrientation {
  case horizontal
  case vertical

  var horizontal: Bool { self == .horizontal }
  var vertical: Bool { self == .vertical }
}

/**
 The indication of which managed view is visible, where `primary` is the left or top view
 and `secondary` is the other one.
 */
public enum SplitViewSideVisible {
  case primary
  case secondary
  case both

  public var primary: Bool { self == .primary || self == .both }
  public var secondary: Bool { self == .secondary || self == .both }
  public var both: Bool { self == .both }
}

/**
 Observable container holding a divider position value.
 */
@MainActor
public final class SplitViewPositionContainer: ObservableObject {
  @Published public var value: CGFloat { didSet { setter?(value) } }

  public var getter: Optional<()->CGFloat> = .none
  public var setter: Optional<(CGFloat)->Void> = .none

  public init(
    _ value: CGFloat = 0.0,
    getter: Optional<() -> CGFloat> = .none,
    setter: Optional<(CGFloat) -> Void> = .none
  ) {
    self.value = value
    self.getter = getter
    self.setter = setter
  }

  func setValue(_ value: CGFloat) { self.value = value }
}

/**
 Observable container holding a SplitViewSideVisible value.
 */
@dynamicMemberLookup
public final class SplitViewSideVisibleContainer: ObservableObject {
  @Published public var value: SplitViewSideVisible { didSet { setter?(value) } }

  public var getter: Optional<()->SplitViewSideVisible> = .none
  public var setter: Optional<(SplitViewSideVisible)->Void> = .none

  public init(
    _ value: SplitViewSideVisible = .both,
    getter: Optional<() -> SplitViewSideVisible> = .none,
    setter: Optional<(SplitViewSideVisible) -> Void> = .none
  ) {
    self.value = value
    self.getter = getter
    self.setter = setter
  }

  subscript<T>(dynamicMember keyPath: KeyPath<SplitViewSideVisible, T>) -> T {
    value[keyPath: keyPath]
  }

  func setValue(_ value: SplitViewSideVisible) {
    self.value = value
  }
}

/**
 Configurable parameters for a SplitView divider. They mostly affect drag movements and behavior.
 */
public struct SplitViewDividerConstraints {
  /// The minimum fraction that the primary view will be constrained within. A value of `nil` means unconstrained.
  var minPrimaryFraction: CGFloat?
  /// The minimum fraction that the secondary view will be constrained within. A value of `nil` means unconstrained.
  var minSecondaryFraction: CGFloat?
  /// Whether to hide the primary side when dragging stops past minPFraction
  var dragToHidePrimary: Bool
  /// Whether to hide the secondary side when dragging stops past minSFraction
  var dragToHideSecondary: Bool
  /// The visible span of the divider view. The actual hit area for touch events can be larger
  var visibleSpan: CGFloat

  public init(
    minPrimaryFraction: CGFloat? = nil,
    minSecondaryFraction: CGFloat? = nil,
    dragToHidePrimary: Bool = false,
    dragToHideSecondary: Bool = false,
    visibleSpan: CGFloat = 16.0
  ) {
    self.minPrimaryFraction = minPrimaryFraction
    self.minSecondaryFraction = minSecondaryFraction
    self.dragToHidePrimary = dragToHidePrimary
    self.dragToHideSecondary = dragToHideSecondary
    self.visibleSpan = visibleSpan
  }
}

/**
 Custom view that manages `primary` and a `secondary` views separated by a divider view. The divider
 recognices drag gestures to change the size of the managed views. It also supports a double-tap
 gesture that will close/hide one of the views when alloed in the `constraints` settings.
 */
public struct SplitView<P, D, S>: View where P: View, D: View, S: View {
  private let orientation: SplitViewOrientation
  private let constraints: SplitViewDividerConstraints
  private let primaryContent: () -> P
  private let secondaryContent: () -> S
  private let dividerContent: () -> D

  // NOTE to self: remember to use @StateObject in parent views for these objects
  @ObservedObject private var sideVisible: SplitViewSideVisibleContainer
  @ObservedObject private var position: SplitViewPositionContainer

  /// The start of the current drag gesture
  @State private var initialPosition: CGFloat?
  /// The last drag position that did not end up with a view disappearing
  @State private var lastPosition: CGFloat = .zero
  /// The side that is going to be hidden due to a drag action
  @State private var highlightSide: SplitViewSideVisible?

  public var body: some View {
    GeometryReader { geometry in
      let size = geometry.size
      let width = size.width
      let height = size.height
      let span: CGFloat = orientation.horizontal ? width : height
      let handleSpan: CGFloat = constraints.visibleSpan
      let handleSpan2: CGFloat = handleSpan / 2
      let dividerPos = position.value * span
      let primarySpan = dividerPos - handleSpan2
      let secondarySpan = span - primarySpan - handleSpan
      let primaryAndHandleSpan = primarySpan + handleSpan

      let primaryFrame: CGSize = orientation.horizontal
      ? .init(width: sideVisible.secondary ? primarySpan : span, height: height)
      : .init(width: width, height: sideVisible.secondary ? primarySpan : span)

      let primaryOffset: CGSize = orientation.horizontal
      ? .init(width: sideVisible.primary ? 0 : -primaryAndHandleSpan, height: 0)
      : .init(width: 0, height: sideVisible.primary ? 0 : -primaryAndHandleSpan)

      let secondaryFrame: CGSize = orientation.horizontal
      ? .init(width: sideVisible.primary ? secondarySpan : span, height: height)
      : .init(width: width, height: sideVisible.primary ? secondarySpan : span)

      let secondaryOffset: CGSize = orientation.horizontal
      ? .init(width: sideVisible.both ? primaryAndHandleSpan : (sideVisible.primary ? span + handleSpan: 0), height: 0)
      : .init(width: 0, height: sideVisible.both ? primaryAndHandleSpan : (sideVisible.primary ? span + handleSpan : 0))

      let dividerOffset = (sideVisible.both ? dividerPos : (sideVisible.primary ? span + handleSpan2 : -handleSpan2))
      let dividerPt: CGPoint = orientation.horizontal
      ? .init(x: dividerOffset, y: height / 2)
      : .init(x: width / 2, y: dividerOffset)

      ZStack(alignment: .topLeading) {
        primaryContent()
          .zIndex(sideVisible.primary ? 0 : -1)
          .frame(width: primaryFrame.width, height: primaryFrame.height)
          .blur(radius: highlightSide == .primary ? 3 : 0, opaque: false)
          .offset(primaryOffset)
          .allowsHitTesting(sideVisible.primary)

        secondaryContent()
          .zIndex(sideVisible.secondary ? 0 : -1)
          .frame(width: secondaryFrame.width, height: secondaryFrame.height)
          .blur(radius: highlightSide == .secondary ? 3 : 0, opaque: false)
          .offset(secondaryOffset)
          .allowsHitTesting(sideVisible.secondary)

        dividerContent()
          .position(dividerPt)
          .zIndex(sideVisible.both ? 1 : -1)
          .onTapGesture(count: 2) {
            if constraints.dragToHidePrimary {
              withAnimation {
                sideVisible.setValue(.secondary)
              }
            } else if constraints.dragToHideSecondary {
              withAnimation {
                sideVisible.setValue(.primary)
              }
            }
          }
          .simultaneousGesture(
            drag(in: span, change: orientation.horizontal ? \.translation.width : \.translation.height)
          )
      }
      .clipped()
    }
  }

  public init(
    orientation: SplitViewOrientation,
    @ViewBuilder primary: @escaping ()-> P,
    @ViewBuilder divider: @escaping () -> D,
    @ViewBuilder secondary: @escaping () -> S
  ) {
    self.init(
      orientation: orientation,
      position: .init(0.5),
      sideVisible: .init(),
      dividerConstraints: .init(),
      primary: primary,
      divider: divider,
      secondary: secondary
    )
  }

  public init(
    orientation: SplitViewOrientation,
    position: SplitViewPositionContainer,
    @ViewBuilder primary: @escaping ()-> P,
    @ViewBuilder divider: @escaping () -> D,
    @ViewBuilder secondary: @escaping () -> S
  ) {
    self.init(
      orientation: orientation,
      position: position,
      sideVisible: .init(),
      dividerConstraints: .init(),
      primary: primary,
      divider: divider,
      secondary: secondary
    )
  }

  public init(
    orientation: SplitViewOrientation,
    position: SplitViewPositionContainer,
    sideVisible: SplitViewSideVisibleContainer,
    @ViewBuilder primary: @escaping ()-> P,
    @ViewBuilder divider: @escaping () -> D,
    @ViewBuilder secondary: @escaping () -> S
  ) {
    self.init(
      orientation: orientation,
      position: position,
      sideVisible: sideVisible,
      dividerConstraints: SplitViewDividerConstraints(),
      primary: primary,
      divider: divider,
      secondary: secondary
    )
  }

  init(
    orientation: SplitViewOrientation,
    position: SplitViewPositionContainer,
    sideVisible: SplitViewSideVisibleContainer,
    dividerConstraints: SplitViewDividerConstraints,
    @ViewBuilder primary: @escaping ()-> P,
    @ViewBuilder divider: @escaping () -> D,
    @ViewBuilder secondary: @escaping () -> S
  ) {
    self.orientation = orientation
    self.position = position
    self.sideVisible = sideVisible
    self.constraints = dividerConstraints
    self.primaryContent = primary
    self.secondaryContent = secondary
    self.dividerContent = divider
  }

  public func positionValue(_ value: SplitViewPositionContainer) -> Self {
    .init(
      orientation: orientation,
      position: value,
      sideVisible: sideVisible,
      dividerConstraints: constraints,
      primary: primaryContent,
      divider: dividerContent,
      secondary: secondaryContent
    )
  }

  public func sideVisible(_ value: SplitViewSideVisibleContainer) -> Self {
    .init(
      orientation: orientation,
      position: position,
      sideVisible: value,
      dividerConstraints: constraints,
      primary: primaryContent,
      divider: dividerContent,
      secondary: secondaryContent
    )
  }

  public func dividerConstraints(_ value: SplitViewDividerConstraints) -> Self {
    .init(
      orientation: orientation,
      position: position,
      sideVisible: sideVisible,
      dividerConstraints: value,
      primary: primaryContent ,
      divider: dividerContent ,
      secondary: secondaryContent
    )
  }

  private func drag(in span: CGFloat, change: KeyPath<DragGesture.Value, CGFloat>) -> some Gesture {
    return DragGesture(coordinateSpace: .global)
      .onChanged { gesture in
        if let initialPosition {
          let unconstrained = max(0, min(span, initialPosition + gesture[keyPath: change])) / span
          position.setValue(max(lowerBound, min(upperBound, unconstrained)))
          if position.value < minPrimarySpan {
            highlightSide = .primary
          } else if position.value > minSecondarySpan {
            highlightSide = .secondary
          } else {
            highlightSide = .none
          }
        } else {
          lastPosition = position.value
          initialPosition = position.value * span
        }
      }
      .onEnded { gesture in
        if position.value < minPrimarySpan {
          sideVisible.setValue(.secondary)
          position.setValue(lastPosition)
        } else if position.value > minSecondarySpan {
          sideVisible.setValue(.primary)
          position.setValue(lastPosition)
        } else {
          position.setValue(max(minPrimarySpan, min(minSecondarySpan, position.value)))
        }
        initialPosition = nil
        highlightSide = nil
      }
  }

  private var minPrimarySpan: CGFloat { constraints.minPrimaryFraction ?? 0.0 }
  private var minSecondarySpan: CGFloat { 1.0 - (constraints.minSecondaryFraction ?? 0.0) }

  private var lowerBound: CGFloat { constraints.dragToHidePrimary ? 0.0 : minPrimarySpan }
  private var upperBound: CGFloat { constraints.dragToHideSecondary ? 1.0 : minSecondarySpan }
}

public struct DebugDivider: View {
  private let orientation: SplitViewOrientation
  public let visibleSpan: CGFloat = 16
  public let invisibleSpan: CGFloat = 32

  init(for orientation: SplitViewOrientation) {
    self.orientation = orientation == .horizontal ? .vertical : .horizontal
  }

  public var body: some View {
    ZStack(alignment: .center) {
      Color.blue.opacity(0.50)
        .frame(width: orientation.horizontal ? nil : invisibleSpan,
               height: orientation.horizontal ? invisibleSpan : nil)
      Color.red.opacity(1.0)
        .frame(width: orientation.horizontal ? nil : visibleSpan,
               height: orientation.horizontal ? visibleSpan : nil)
    }
  }
}

public struct DemoHSplit: View {
  @StateObject var sideVisible = SplitViewSideVisibleContainer(.primary)
  @StateObject var position = SplitViewPositionContainer(0.5)

  public var body: some View {
    let _ = Self._printChanges()
    SplitView(
      orientation: .horizontal,
      position: position,
      sideVisible: sideVisible,
      dividerConstraints: .init(minPrimaryFraction: 0.3, minSecondaryFraction: 0.2, dragToHideSecondary: true)
    ) {
      VStack {
        Button(sideVisible.value == .both ? "Hide Right" : "Show Right") {
          withAnimation {
            sideVisible.setValue(sideVisible.both ? .primary : .both)
          }
        }
      }
      .frame(maxWidth: .infinity, maxHeight: .infinity)
      .background(Color.green)
    } divider: {
      DebugDivider(for: .horizontal)
    } secondary: {
      VStack {
        Button(sideVisible.both ? "Hide Left" : "Show Left") {
          withAnimation {
            sideVisible.setValue(sideVisible.both ? .secondary : .both)
          }
        }
      }
      .frame(maxWidth: .infinity, maxHeight: .infinity)
      .background(Color.orange)
    }
    .positionValue(position)
    .sideVisible(sideVisible)
    .dividerConstraints(.init(minPrimaryFraction: 0.3, minSecondaryFraction: 0.2, dragToHideSecondary: true))
  }
}

public struct DemoVSplit: View {
  @StateObject var sideVisible = SplitViewSideVisibleContainer(.both)
  @StateObject var position = SplitViewPositionContainer(0.3)

  public init() {}

  public var body: some View {
    let _ = Self._printChanges()
    SplitView(orientation: .vertical, position: position, sideVisible: sideVisible) {
      VStack {
        Button(sideVisible.both ? "Hide Bottom" : "Show Bottom") {
          withAnimation {
            sideVisible.setValue(sideVisible.both ? .primary : .both)
          }
        }
      }
      .frame(maxWidth: .infinity, maxHeight: .infinity)
      .background(Color.mint)
    } divider: {
      DebugDivider(for: .vertical)
    } secondary: {
      HStack {
        VStack {
          Button(sideVisible.both ? "Hide Top" : "Show Top") {
            withAnimation {
              sideVisible.setValue(sideVisible.both ? .secondary : .both)
            }
          }
        }.contentShape(Rectangle())
        DemoHSplit()
      }
      .frame(maxWidth: .infinity, maxHeight: .infinity)
      .background(Color.teal)
    }
  }
}

extension View {
  @ViewBuilder public func isHidden(_ hidden: Bool) -> some View {
    if hidden {
      self.hidden()
    } else {
      self
    }
  }
}

struct Split_Previews: PreviewProvider {
  static var previews: some View {
    DemoVSplit()
  }
}

struct HandleDivider: View {
  let orientation: SplitViewOrientation
  let dividerConstraints: SplitViewDividerConstraints
  let handleColor: Color
  let handleLength: CGFloat
  let paddingInsets: CGFloat
  init(
    orientation: SplitViewOrientation,
    dividerConstraints: SplitViewDividerConstraints,
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

#Preview {
  HandleDivider(
    orientation: .horizontal,
    dividerConstraints: .init(
      minPrimaryFraction: 0.3,
      minSecondaryFraction: 0.3,
      dragToHidePrimary: false,
      dragToHideSecondary: false,
      visibleSpan: 16.0
    ),
    handleColor: Color.blue,
    handleLength: 48,
    paddingInsets: 8
  )
}
