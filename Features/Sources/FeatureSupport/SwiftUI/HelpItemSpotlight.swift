// Copyright © 2026 Brad Howes. All rights reserved.
//
// Based on code from: https://github.com/Livsy90/TutorialSpotlight

import SwiftUI

extension View {

  /**
   Adds a help item spotlight overlay to a view. Mark focusable elements with `helpItem(id:)` view modifier.

   - parameter selection: binding to use to control activation of spotlight and the item to highlight.
   - parameter orderedIDs: collection of unique values to cycle through to highlight.
   - parameter spotlightPadding: padding to apply to the spotlight overlay
   - parameter cornerRadius: corner radius to apply to the spotlight overlay
   */
  public func helpItemSpotlight<ID: Hashable, Overlay: View>(
    selection: Binding<ID?>,
    orderedIDs: [ID],
    spotlightPadding: CGFloat = 8,
    cornerRadius: CGFloat = 28,
    @ViewBuilder overlay: @escaping (_ id: ID, _ actions: HelpItemSpotlightActions) -> Overlay
  ) -> some View {
    modifier(
      HelpItemSpotlightModifier(
        selection: selection,
        orderedIDs: orderedIDs,
        spotlightPadding: spotlightPadding,
        cornerRadius: cornerRadius,
        overlay: overlay
      )
    )
  }

  /**
   Assign a HelpItem value to a view.

   - parameter id: the value to assign
   - returns: modified view
   */
  public func helpItem<ID: Hashable>(id: ID) -> some View {
    modifier(HelpItemModifier(id: id))
  }
}

/**
 Collection of actions available in a help spotlight panel overlay.
 */
public struct HelpItemSpotlightActions {
  /// Closes the spotlight flow and removes the overlay.
  public let dismiss: () -> Void
  /// Move to the previous spotlight item in `orderedIDs`.
  public let previous: () -> Void
  /// Move to the next spotlight item in `orderedIDs`.
  public let next: () -> Void
}

/**
 Mapping of view help item ID tags and view bounds made available via SwiftUI preferences system.
 */
private struct HelpItemPreferenceKey<ID: Hashable>: PreferenceKey {
  typealias Value = [ID: Anchor<CGRect>]

  static var defaultValue: Value { [:] }

  static func reduce(value: inout Value, nextValue: () -> Value) {
    value.merge(nextValue()) { (_, new) in new }
  }
}

/**
 View modifier that adds a help item preference value. Use `transformAnchorPreference` so that containers do not shadow
 entities they hold. Since the default value is an empty dictionary, this is also safe to use for non-container views.
 */
private struct HelpItemModifier<ID: Hashable>: ViewModifier {
  let id: ID
  @Environment(\.helpSpotlightNamespace) private var namespace

  func body(content: Content) -> some View {
    content
      .matchedGeometryEffect(id: id, in: namespace.id, properties: .frame, anchor: .center, isSource: true)
      .transformAnchorPreference(key: HelpItemPreferenceKey<ID>.self, value: .bounds) {
        $0[id] = $1
      }
  }
}

/**
 View modifier that handles the display of a spotlight on a help item.
 */
private struct HelpItemSpotlightModifier<ID: Hashable, Overlay: View>: ViewModifier {
  typealias Value = HelpItemPreferenceKey<ID>.Value

  @Binding var selection: ID?
  let orderedIDs: [ID]
  let spotlightPadding: CGFloat
  let cornerRadius: CGFloat
  let overlay: (ID, HelpItemSpotlightActions) -> Overlay
  let animationDuration = 0.8

  @State private var overlaySize: CGSize = .zero
  @Namespace private var spotlightAnimation
  @Environment(\.colorScheme) private var colorScheme

  func body(content: Content) -> some View {
    content
      .coordinateSpace(name: HelpItemSpotlightCoordinateSpace.name)
      .helpItemSpotlightAnimationNamespace(spotlightAnimation)
    .overlayPreferenceValue(HelpItemPreferenceKey<ID>.self) { preferences in
      GeometryReader { proxy in
        spotlightOverlayContent(preferences: preferences, proxy: proxy)
          .frame(maxWidth: .infinity, maxHeight: .infinity)
      }
      .animation(.smooth(duration: animationDuration), value: selection)
    }
  }

  private func dismissAction() {
    selection = nil
  }

  private func previousAction(selected: ID, preferences: Value) {
    guard var index = orderedIDs.firstIndex(of: selected) else {
      selection = nil
      return
    }

    while true {
      index = index == orderedIDs.startIndex ? orderedIDs.endIndex - 1 : orderedIDs.index(before: index)
      let previous = orderedIDs[index]
      if preferences[previous] != nil {
        selection = previous
        break
      }
    }
  }

  private func nextAction(selected: ID, preferences: Value) {
    guard var index = orderedIDs.firstIndex(of: selected) else {
      selection = nil
      return
    }

    while true {
      index = index == orderedIDs.endIndex - 1 ? orderedIDs.startIndex : orderedIDs.index(after: index)
      let next = orderedIDs[index]
      if preferences[next] != nil {
        selection = next
        break
      }
    }
  }

  private func adjustedFocusFrame(proxy: GeometryProxy, focusFrame: CGRect) -> CGRect {
    let displayedFocusFrame = focusFrame
    let safeAreaInsets = proxy.safeAreaInsets
    return displayedFocusFrame.offsetBy(dx: safeAreaInsets.leading, dy: safeAreaInsets.top)
  }

  private var spotlightBackingColor: Color {
    colorScheme == .light ? .black : .white
  }

  private func spotlight(bounds: CGRect) -> some View {
    ZStack {
      spotlightBackingColor
      RoundedRectangle(cornerRadius: cornerRadius)
        .frame(width: bounds.width, height: bounds.height)
        .position(x: bounds.midX, y: bounds.midY)
        .matchedGeometryEffect(id: selection, in: spotlightAnimation, properties: .frame, anchor: .center, isSource: false)
        .foregroundColor(colorScheme == .light ? .white : .black)
        .blur(radius: 6)
        .blendMode(.destinationOut)
    }
    .compositingGroup()
    .opacity(0.7)
    .contentShape(.rect)
    .onTapGesture {
      dismissAction()
    }
  }

  private func helpInfoPanel(selected: ID, actions: HelpItemSpotlightActions, position: CGPoint, maxWidth: CGFloat) -> some View {
    overlay(selected, actions)
      .frame(maxWidth: maxWidth)
      .background {
        GeometryReader { overlayProxy in
          Color.clear
            .preference(key: HelpItemSpotlightOverlaySizePreferenceKey.self, value: overlayProxy.size)
        }
      }
      .clipped()
      .position(position)
  }

  @ViewBuilder
  private func spotlightOverlayContent(preferences: Value, proxy: GeometryProxy) -> some View {
    if let selected = selection, let anchor = preferences[selected] {
      let actions = HelpItemSpotlightActions(
        dismiss: { self.dismissAction() },
        previous: { self.previousAction(selected: selected, preferences: preferences) },
        next: { self.nextAction(selected: selected, preferences: preferences) }
      )

      let focusFrame = proxy[anchor].insetBy(dx: -spotlightPadding, dy: -spotlightPadding)
      let containerBounds = proxy.containerBounds
      let spotlightFrame = adjustedFocusFrame(proxy: proxy, focusFrame: focusFrame)
      let position = overlayPosition(for: spotlightFrame, in: containerBounds)

      ZStack(alignment: .topLeading) {
        spotlight(bounds: spotlightFrame)
        helpInfoPanel(
          selected: selected,
          actions: actions,
          position: position,
          maxWidth: min(320, containerBounds.width - 32)
        )
      }
      .frame(width: containerBounds.width, height: containerBounds.height)
      .offset(x: -proxy.safeAreaInsets.leading, y: -proxy.safeAreaInsets.top)
      .onPreferenceChange(HelpItemSpotlightOverlaySizePreferenceKey.self) {
        overlaySize = $0
      }
      .animation(.smooth(duration: animationDuration), value: selection)
      .animation(.smooth(duration: animationDuration), value: position)
      .animation(.smooth(duration: animationDuration), value: overlaySize)
    } else {
      EmptyView()
    }
  }

  private func overlayPosition(for overlayFrame: CGRect, in container: CGRect) -> CGPoint {
    // Keep a consistent margin around the overlay so it never touches screen edges.
    let horizontalPadding: CGFloat = 16
    let verticalSpacing: CGFloat = 24
    let verticalPadding: CGFloat = 24

    // Cap the overlay width to a readable maximum while still respecting
    // the available horizontal space inside the container.
    let maxOverlayWidth = min(320, container.width - (horizontalPadding * 2))

    // Use the measured overlay size when available. Fallback values are used
    // during the first layout pass, before SwiftUI reports the actual size.
    let measuredWidth = overlaySize.width > 0 ? overlaySize.width : maxOverlayWidth
    let measuredHeight = overlaySize.height > 0 ? overlaySize.height : 180
    let overlayWidth = min(measuredWidth, maxOverlayWidth)

    // Try to align the overlay horizontally with the highlighted target,
    // then clamp the center point so the card stays fully visible on screen.
    let centeredX = min(
      max(overlayFrame.midX, container.minX + horizontalPadding + overlayWidth / 2),
      container.maxX - horizontalPadding - overlayWidth / 2
    )

    // The preferred placement is below the spotlight. We compute the Y center
    // by taking the target's bottom edge, adding vertical spacing, and then
    // shifting by half of the overlay height because `.position` works from center.
    let preferredBelowY = overlayFrame.maxY + verticalSpacing + measuredHeight / 2

    // If the entire overlay still fits within the bottom safe area margin,
    // keep it below the spotlight because that is the primary visual layout.
    if preferredBelowY + measuredHeight / 2 <= container.maxY - verticalPadding {
      return .init(x: centeredX, y: preferredBelowY)
    }

    // Otherwise, move the overlay above the spotlight using the same center-based
    // coordinate calculation.
    let preferredAboveY = overlayFrame.minY - verticalSpacing - measuredHeight / 2

    // Clamp the final vertical position so the overlay remains fully inside
    // the visible container even when there is not enough room above either.
    let clampedY = min(
      max(preferredAboveY, container.minY + verticalPadding + measuredHeight / 2),
      container.maxY - verticalPadding - measuredHeight / 2
    )
    return .init(x: centeredX, y: clampedY)
  }
}

private struct HelpItemSpotlightCutoutShape: Shape {
  let focusFrame: CGRect
  let cornerRadius: CGFloat

  func path(in rect: CGRect) -> Path {
    var path = Path()
    path.addRect(rect)
    path.addPath(
      RoundedRectangle(cornerRadius: cornerRadius)
        .path(in: focusFrame)
    )
    return path
  }
}

// swiftlint:disable:next type_name
private struct HelpItemSpotlightOverlaySizePreferenceKey: PreferenceKey {
  // A simple preference channel used to bubble the measured overlay size upward.
  static var defaultValue: CGSize { .zero }

  static func reduce(value: inout CGSize, nextValue: () -> CGSize) {
    value = nextValue()
  }
}

private enum HelpItemSpotlightCoordinateSpace {
  // Shared coordinate space name used by spotlight sources and the container.
  static let name = "helpItemSpotlightCoordinateSpace"
}

fileprivate extension GeometryProxy {

  var containerBounds: CGRect {
    .init(
      origin: .zero,
      size: .init(
        width: size.width + safeAreaInsets.leading + safeAreaInsets.trailing,
        height: size.height + safeAreaInsets.top + safeAreaInsets.bottom
      )
    )
  }
}

/**
 Container to hold the custom namespace for help spotlight animations.
 */
@Observable
private final class HelpSpotlightNamespace {
  public var id: Namespace.ID!

  init(_ namespace: Namespace.ID? = nil) {
    if let namespace = namespace {
      self.id = namespace
    }
  }
}

/**
 Custom EnvironmentKey for the help spotlight namespace.
 */
private struct HelpSpotlightNamespaceEnvironmentKey: EnvironmentKey {
  fileprivate static var defaultValue: HelpSpotlightNamespace { HelpSpotlightNamespace() }
}

extension EnvironmentValues {

  /// Custom EnvironmentValues property that provides the help spotlight animation namespace.
  fileprivate var helpSpotlightNamespace: HelpSpotlightNamespace {
    get { self[HelpSpotlightNamespaceEnvironmentKey.self] }
    set { self[HelpSpotlightNamespaceEnvironmentKey.self] = newValue }
  }
}

extension View {

  fileprivate func helpItemSpotlightAnimationNamespace(_ value: Namespace.ID) -> some View {
    environment(\.helpSpotlightNamespace, HelpSpotlightNamespace(value))
  }
}

#if DEBUG

@available(iOS 16.0)
#Preview {
  struct TutorialSpotlightDemo: View {
    // Demo steps used to show how the spotlight moves through multiple targets.
    enum Step: String, CaseIterable {
      case profile
      case filters
      case checkout

      var title: String {
        switch self {
        case .profile: "Profile"
        case .filters: "Filters"
        case .checkout: "Checkout"
        }
      }

      var message: String {
        switch self {
        case .profile: "Here the user quickly gets to their profile and account settings."
        case .filters: "This block manages filters. It's usually the second step in onboarding."
        case .checkout: "The button completes the scenario. The final step may lead to payment or confirmation."
        }
      }

      var buttonTitle: String {
        switch self {
        case .checkout: "Finish"
        default: "Next"
        }
      }
    }

    enum SheetStep: String, CaseIterable {
      case title
      case action

      var title: String {
        switch self {
        case .title: "Sheet Header"
        case .action: "Primary Action"
        }
      }

      var message: String {
        switch self {
        case .title: "This title explains the purpose of the modal flow."
        case .action: "This button confirms the choice and closes the scenario."
        }
      }

      var buttonTitle: String {
        switch self {
        case .title: "Next"
        case .action: "Done"
        }
      }
    }

    // Start the preview with the first onboarding step already selected.
    @State private var selection: Step?

    @State private var showSheet: Bool = false

    var body: some View {
      NavigationStack {
        ScrollView {
          VStack(spacing: 24) {
            VStack(alignment: .leading, spacing: 12) {
              Text("Travel Planner")
                .font(.largeTitle.bold())

              Text("Build a trip, fine-tune filters, and finish booking in a couple of taps.")
                .foregroundStyle(.secondary)

              HStack(spacing: 12) {
                statCard(title: "12", subtitle: "Routes")
                statCard(title: "5", subtitle: "Cities")
                statCard(title: "3", subtitle: "Days")
              }
            }
            .frame(maxWidth: .infinity, alignment: .leading)

            filterPanel
              .helpItem(id: Step.filters)

            Button("Show Sheet") {
              showSheet.toggle()
            }
          }
          .padding(24)
        }
        .background {
          LinearGradient(
            colors: [
              Color(red: 0.94, green: 0.95, blue: 0.98),
              Color(red: 0.88, green: 0.92, blue: 0.97),
              Color(red: 0.83, green: 0.89, blue: 0.95)
            ],
            startPoint: .topLeading,
            endPoint: .bottomTrailing
          )
          .ignoresSafeArea()
        }
        .navigationTitle("Discover")
        .navigationBarTitleDisplayMode(.inline)
        .toolbar {
          ToolbarItem(placement: .topBarTrailing) {
            // Register the toolbar button as a spotlight source.
            profileButton
              .helpItem(id: Step.profile)
          }
        }
        .safeAreaInset(edge: .bottom) {
          // Register the bottom call-to-action as another spotlight source.
          checkoutButton
            .helpItem(id: Step.checkout)
            .padding()
        }
      }
      .sheet(isPresented: $showSheet) {
        SheetSpotlightDemo()
      }
      // Attach the spotlight container to a common ancestor so it can resolve
      // every registered target and draw one shared overlay above the screen.
      .helpItemSpotlight(
        selection: $selection,
        orderedIDs: Step.allCases
      ) { id, actions in
        spotlightCard(for: id, actions: actions)
      }
    }

    private var profileButton: some View {
      Button {
        selection = .profile
      } label: {
        Image(systemName: "person.crop.circle.fill")
      }
    }

    private var filterPanel: some View {
      VStack(alignment: .leading, spacing: 14) {
        Text("Smart Filters")
          .font(.headline)

        HStack(spacing: 10) {
          chip("Budget")
          chip("Family")
          chip("Food")
        }

        HStack(spacing: 14) {
          filterMetric(title: "Price", value: "$420")
          filterMetric(title: "Rating", value: "4.8")
          filterMetric(title: "Transit", value: "18 min")
        }
      }
      .padding(20)
      .frame(maxWidth: .infinity, alignment: .leading)
      .background(
        .white.opacity(0.82),
        in: .rect(cornerRadius: 28)
      )
    }

    private var checkoutButton: some View {
      Button {
        selection = .checkout
      } label: {
        HStack {
          Text("Continue")
          Spacer()
          Image(systemName: "arrow.right")
        }
        .font(.headline)
        .foregroundStyle(.white)
        .padding(.horizontal, 22)
        .padding(.vertical, 20)
        .frame(maxWidth: .infinity)
        .background(
          LinearGradient(
            colors: [.indigo, .cyan],
            startPoint: .leading,
            endPoint: .trailing
          ),
          in: .rect(cornerRadius: 24)
        )
      }
      .buttonStyle(.plain)
    }

    private func statCard(
      title: String,
      subtitle: String
    ) -> some View {
      VStack(alignment: .leading, spacing: 6) {
        Text(title)
          .font(.title3.bold())
        Text(subtitle)
          .foregroundStyle(.secondary)
      }
      .padding()
      .frame(maxWidth: .infinity, alignment: .leading)
      .background(
        .white.opacity(0.82),
        in: .rect(cornerRadius: 12)
      )
    }

    private func chip(_ title: String) -> some View {
      Text(title)
        .font(.subheadline.weight(.semibold))
        .padding(.horizontal, 12)
        .padding(.vertical, 8)
        .background(.blue.opacity(0.12), in: Capsule())
    }

    private func filterMetric(
      title: String,
      value: String
    ) -> some View {
      VStack(alignment: .leading, spacing: 4) {
        Text(title)
          .font(.caption)
          .foregroundStyle(.secondary)
        Text(value)
          .font(.headline)
      }
      .frame(maxWidth: .infinity, alignment: .leading)
    }

    private func spotlightCard(
      for step: Step,
      actions: HelpItemSpotlightActions
    ) -> some View {
      VStack(alignment: .leading, spacing: 16) {
        Text(step.title)
          .font(.title3.weight(.bold))
        Text(step.message)
          .foregroundStyle(.secondary)
        HStack {
          Button("Previous") { actions.previous() }
          Spacer()
          Button("Next") { actions.next() }
        }
        .fontWeight(.semibold)
      }
      .padding(20)
      .background {
        RoundedRectangle(cornerRadius: 28)
          .fill(.white)
          .stroke(.red, lineWidth: 1)
      }
      .shadow(color: .black.opacity(0.12), radius: 24, y: 12)
    }
  }

  struct SheetSpotlightDemo: View {
    @Environment(\.dismiss) private var dismiss
    @State private var selection: TutorialSpotlightDemo.SheetStep?

    var body: some View {
      NavigationStack {
        VStack(alignment: .leading, spacing: 24) {
          VStack(alignment: .leading, spacing: 12) {
            Text("Plan Summary")
              .font(.title2.bold())
              .helpItem(id: TutorialSpotlightDemo.SheetStep.title)

            Text("Review the details in the sheet before confirming the selection.")
              .foregroundStyle(.secondary)

            Button("Start tutorial") {
              selection = .title
            }
          }

          VStack(spacing: 14) {
            summaryRow(title: "Destination", value: "Lisbon")
            summaryRow(title: "Dates", value: "May 12 - May 16")
            summaryRow(title: "Guests", value: "2 adults")
          }
          .padding(18)
          .frame(maxWidth: .infinity, alignment: .leading)
          .background(.thinMaterial, in: .rect(cornerRadius: 24))

          Spacer()

          Button {
            dismiss()
          } label: {
            Text("Confirm")
              .font(.headline)
              .foregroundStyle(.white)
              .frame(maxWidth: .infinity)
              .padding(.vertical, 18)
              .background(.blue.gradient, in: .rect(cornerRadius: 18))
          }
          .buttonStyle(.plain)
          .helpItem(id: TutorialSpotlightDemo.SheetStep.action)
        }
        .padding(24)
        .navigationTitle("Booking")
        .navigationBarTitleDisplayMode(.inline)
      }
      .presentationDetents([.medium, .large])
      .helpItemSpotlight(
        selection: $selection,
        orderedIDs: TutorialSpotlightDemo.SheetStep.allCases
      ) { id, actions in
        VStack(alignment: .leading, spacing: 16) {
          Text(id.title)
            .font(.headline)

          Text(id.message)
            .foregroundStyle(.secondary)

          HStack {
            Button("Close") {
              actions.dismiss()
            }
            .buttonStyle(.plain)
            .foregroundStyle(.secondary)

            Spacer()

            Button(id.buttonTitle) {
              if id == .action {
                dismiss()
              } else {
                actions.next()
              }
            }
            .fontWeight(.semibold)
          }
        }
        .padding(20)
        .background(.white, in: .rect(cornerRadius: 24))
        .shadow(color: .black.opacity(0.12), radius: 20, y: 10)
      }
    }

    private func summaryRow(title: String, value: String) -> some View {
      HStack {
        Text(title)
          .foregroundStyle(.secondary)
        Spacer()
        Text(value)
          .fontWeight(.semibold)
      }
    }
  }

  return TutorialSpotlightDemo()
}

#endif // DEBUG
