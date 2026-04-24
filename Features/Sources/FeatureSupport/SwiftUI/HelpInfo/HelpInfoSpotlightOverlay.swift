// Copyright © 2026 Brad Howes. All rights reserved.
//
// Based on code by Artem Mirzabekian -- https://github.com/Livsy90/TutorialSpotlight

import SwiftUI

extension View {

  /**
   Adds a help item spotlight overlay to a view.

   The overlay appears when the given binding holds a non-nil value. The items that are highlighted must be tagged with the
   ``helpInfoViewTag(_:)`` view modifier. The spotlight overlay consists of two visual components:

   - a 'spotlight' that visually focuses attention to an item in the display
   - an info panel that shows help content for the item being spotlit

   The caller provides a view builder that generates the view that shows the help content for the item being spotlit. The view
   builder is called by the `HelpInfoSpotlightOverlay` code with the ID of the current item, and a collection of "actions" that the
   view builder must use to navigate to the next or previous item, or to dismiss the spotlight activity.

   - parameter selection: binding to use to control activation of spotlight and the item to highlight.
   - parameter orderedIDs: collection of unique values to cycle through to highlight.
   - parameter spotlightPadding: padding to apply to the spotlight overlay.
   - parameter cornerRadius: corner radius to apply to the spotlight overlay.
   - parameter animationDuration: the duration of animations involving the help item spotlight.
   - parameter blurRadius: the amount of blur applied to the spotlight region.
   - parameter dimmingOpacity: the amount of dimming applied to the whole app except the area being spotlit.
   - parameter overlay: view builder that constructs the info panel to show with the help text.
   */
  public func helpInfoSpotlightOverlay<ID: Hashable, Overlay: View>(
    selection: Binding<ID?>,
    orderedIDs: [ID],
    spotlightPadding: CGFloat = 8,
    cornerRadius: CGFloat = 28,
    animationDuration: TimeInterval = 0.4,
    blurRadius: CGFloat = 6.0,
    dimmingOpacity: CGFloat = 0.7,
    @ViewBuilder overlay: @escaping (_ id: ID, _ actions: HelpInfoSpotlightOverlayActions) -> Overlay
  ) -> some View {
    modifier(
      HelpInfoSpotlightOverlayModifier(
        selection: selection,
        orderedIDs: orderedIDs,
        spotlightPadding: spotlightPadding,
        cornerRadius: cornerRadius,
        animationDuration: animationDuration,
        blurRadius: blurRadius,
        dimmingOpacity: dimmingOpacity,
        helpInfoGenerator: overlay
      )
    )
  }

  /**
   Assign an ID value to a view to indicate that it has help information.

   - parameter id: the value to assign
   - returns: modified view
   */
  public func helpInfoViewTag<ID: Hashable>(id: ID) -> some View {
    modifier(HelpInfoViewTagModifier(id: id))
  }
}

/**
 Protocol for entities that can provide help information for a view tagged by ``helpInfoViewTag``.
 */
public protocol HelpInfoProvider {

  /// The content to use for the title `Text` view
  var title: LocalizedStringKey { get }
  /// The generator to use for the content of the text `Text` view. This delays `String` interpolation to properly honor embedded
  /// `Image(systemName:)` terms.
  var text: LocalizedStringKey { get }
}

/**
 Example definition of an overlay that presents the help information for a view tagged by ``helpInfoViewTag``. This can be used if
 the `ID` generic implements ``HelpInfoProvider``.

 - parameter item: the ID of the view being spotlit.
 - parameter actions: the collection of actions for buttons in the overlay view
 - returns: overlay view
 */
@MainActor
public func helpInfoOverlay<ID: Hashable & HelpInfoProvider>(for item: ID, actions: HelpInfoSpotlightOverlayActions) -> some View {
  @Environment(\.colorScheme) var colorScheme
  return VStack(spacing: 16) {
    HelpInfoLayout {
      Text(item.title)
        .font(.title3.weight(.bold))
      Text(item.text)
        .foregroundStyle(.secondary)
    }
    .overlay(alignment: .topTrailing) {
      Button {
        actions.dismiss()
      } label: {
        Image(systemName: .cancelButtonImageName)
      }
    }
    HStack(spacing: 24) {
      Button {
        actions.previous()
      } label: {
        Image(systemName: "arrowshape.left.fill")
      }
      Button {
        actions.next()
      } label: {
        Image(systemName: "arrowshape.right.fill")
      }
    }
    .fontWeight(.semibold)
  }
  .padding(20)
  .background {
    RoundedRectangle(cornerRadius: 28)
      .fill(colorScheme == .light ? .white : .black)
  }
  .shadow(color: .black.opacity(0.12), radius: 24, y: 12)
}

/**
 Collection of actions available in a help spotlight info panel overlay.
 */
public struct HelpInfoSpotlightOverlayActions {
  /// Closes the spotlight flow and removes the overlay.
  public let dismiss: () -> Void
  /// Move to the previous item in `orderedIDs`. Skips over items that are not found in the collection of registered views.
  public let previous: () -> Void
  /// Move to the next item in `orderedIDs`. Skips over items that are not found in the collection of registered views.
  public let next: () -> Void
}

/**
 View modifier that handles the display of a spotlight on a help item.

 See ``helpInfoSpotlightOverlay`` View modifier for details.
 */
private struct HelpInfoSpotlightOverlayModifier<ID: Hashable, Overlay: View>: ViewModifier {
  typealias Value = HelpInfoSpotlightOverlayPreferenceKey<ID>.Value

  @Namespace private var spotlightAnimation
  @Environment(\.colorScheme) private var colorScheme

  /// The current view being spotlit.
  @Binding var selection: ID?
  /// The collection of known IDs that may be found in the view attached to this modifier. The ``previous`` and ``next`` actions
  /// rely on the ordering to move the the previous and next values from the currently selected one.
  let orderedIDs: [ID]
  let spotlightPadding: CGFloat
  let cornerRadius: CGFloat
  let animationDuration: TimeInterval
  let blurRadius: CGFloat
  let dimmingOpacity: CGFloat
  let helpInfoGenerator: (ID, HelpInfoSpotlightOverlayActions) -> Overlay

  /// The position of the view displaying the help text. This is dynamically calculated based on the location of the item being
  /// spotlit, and the size of the help text view.
  @State private var position: CGPoint = .zero

  func body(content: Content) -> some View {
    content
      .coordinateSpace(name: HelpInfoSpotlightCoordinateSpace.name)
      .helpInfoSpotlightAnimationNamespace(spotlightAnimation)
      .overlayPreferenceValue(HelpInfoSpotlightOverlayPreferenceKey<ID>.self) { preferences in
        GeometryReader { proxy in
          spotlightOverlayContent(preferences: preferences, proxy: proxy)
        }
        .animation(.smooth(duration: animationDuration), value: selection)
      }
  }

  /**
   Create the spotlight view to hilight an item in the UI and show help text for it.

   This is the main entry point for spotlight overlay. As the ``selection`` value changes, the spotlight will move to the new view,
   and the contents of the info view will change to show the help text for the new view.

   NOTE: the shifting effect looks pretty cool, *but* the help contents jumps to the new position. Ideally, the new text would
   replace the old in the previous location and then move with the panel to the new location. May require using two views with
   ``matchedGeometryEffect`` to properly morph from one to the other.

   - parameter preferences: the collection of known UI elements with `Anchor<CGRect>` values.
   - parameter proxy: a `GeometryProxy` to use to obtain frames for the anchors.
   - returns: new view made up of a spotlight mask and a info view overlay containing the help text for the active item.
   */
  @ViewBuilder
  private func spotlightOverlayContent(preferences: Value, proxy: GeometryProxy) -> some View {
    if let selected = selection, let anchor = preferences[selected] {
      let containerBounds = proxy.containerBounds
      let anchorFrame = proxy[anchor].insetBy(dx: -spotlightPadding, dy: -spotlightPadding)
      let spotlightFrame = anchorFrame.offsetBy(dx: proxy.safeAreaInsets.leading, dy: proxy.safeAreaInsets.top)
      let actions = HelpInfoSpotlightOverlayActions(
        dismiss: { self.dismissAction() },
        previous: { self.previousAction(selected: selected, preferences: preferences) },
        next: { self.nextAction(selected: selected, preferences: preferences) }
      )

      ZStack(alignment: .topLeading) {
        spotlightMask(for: spotlightFrame)
        helpInfoGenerator(selected, actions)
          .onGeometryChange(for: CGSize.self) {
            $0.frame(in: .named(HelpInfoSpotlightCoordinateSpace.name)).size
          } action: { panelSize in
            self.position = helpInfoPosition(for: spotlightFrame, panelSize: panelSize, in: containerBounds)
          }
          .clipped()
          .position(self.position)
      }
      .frame(width: containerBounds.width, height: containerBounds.height)
      .offset(x: -proxy.safeAreaInsets.leading, y: -proxy.safeAreaInsets.top)
      .animation(.smooth(duration: animationDuration), value: selection)
      .animation(.smooth(duration: animationDuration), value: position)
    } else {
      EmptyView()
    }
  }

  private func dismissAction() {
    selection = nil
  }

  private func previousAction(selected: ID, preferences: Value) {
    if var index = orderedIDs.firstIndex(of: selected) {
      for _ in 0..<orderedIDs.count {
        index = index == orderedIDs.startIndex ? orderedIDs.endIndex - 1 : orderedIDs.index(before: index)
        let previous = orderedIDs[index]
        // Only use an ID if there is an anchor for it.
        if preferences[previous] != nil {
          selection = previous
          return
        }
      }
    }
    selection = nil
  }

  private func nextAction(selected: ID, preferences: Value) {
    if var index = orderedIDs.firstIndex(of: selected) {
      for _ in 0..<orderedIDs.count {
        index = index == orderedIDs.endIndex - 1 ? orderedIDs.startIndex : orderedIDs.index(after: index)
        let next = orderedIDs[index]
        // Only use an ID if there is an anchor for it.
        if preferences[next] != nil {
          selection = next
          return
        }
      }
    }
    selection = nil
  }

  private var spotlightBackingColor: Color {
    colorScheme == .light ? .black : .white
  }

  /**
   Create a composite full-screen image that dims everything but the indicated region. Uses `matchedGeometryEffect` so that the
   spotlight animates from one region to the next. Tapping anywhere in the mask will dismiss the spotlight.

   - parameter focusArea: the area to "punch out" to spotlight an area on the screen.
   - returns: new mask view
   */
  private func spotlightMask(for focusArea: CGRect) -> some View {
    ZStack {
      spotlightBackingColor
      RoundedRectangle(cornerRadius: cornerRadius)
        .frame(width: focusArea.width, height: focusArea.height)
        .position(x: focusArea.midX, y: focusArea.midY)
        .matchedGeometryEffect(id: selection, in: spotlightAnimation, properties: .frame, anchor: .center, isSource: false)
        .foregroundColor(colorScheme == .light ? .white : .black)
        .blur(radius: blurRadius)
        .blendMode(.destinationOut)
    }
    .compositingGroup()
    .opacity(dimmingOpacity)
    .contentShape(.rect)
    .onTapGesture {
      dismissAction()
    }
  }

  /**
   Determine a reasonable location for the help info panel which does not obscure the spotlit item and keeps the info panel
   fully on the app display.

   - parameter focusFrame: the frame of the item being spotlit.
   - parameter panelSize: the area of the screen to use for positioning
   - parameter container: the bounds of the view to constrain the placement of the help info view
   - returns: the location to use for the panel
   */
  private func helpInfoPosition(for focusFrame: CGRect, panelSize: CGSize, in container: CGRect) -> CGPoint {
    let horizontalPadding: CGFloat = 16
    let verticalSeparation: CGFloat = 24
    let verticalPadding: CGFloat = 24

    let panelWidth2 = panelSize.width / 2
    let panelHeight2 = panelSize.height / 2

    let centeredX = min(
      max(focusFrame.midX, container.minX + horizontalPadding + panelWidth2),
      container.maxX - horizontalPadding - panelWidth2
    )

    let preferredBelowY = focusFrame.maxY + verticalSeparation + panelHeight2
    let position: CGPoint

    if preferredBelowY + panelHeight2 <= container.maxY - verticalPadding {
      position = .init(x: centeredX, y: preferredBelowY)
    } else {
      let preferredAboveY = focusFrame.minY - verticalSeparation - panelHeight2
      let clampedY = min(
        max(preferredAboveY, container.minY + verticalPadding + panelHeight2),
        container.maxY - verticalPadding - panelHeight2
      )
      position = .init(x: centeredX, y: clampedY)
    }

    return position
  }
}

/**
 Mapping of view help item ID tags and view anchor bounds made available via SwiftUI preferences system.
 */
private struct HelpInfoSpotlightOverlayPreferenceKey<ID: Hashable>: PreferenceKey {
  typealias Value = [ID: Anchor<CGRect>]

  static var defaultValue: Value { [:] }

  static func reduce(value: inout Value, nextValue: () -> Value) {
    value.merge(nextValue()) { (_, new) in new }
  }
}

/**
 View modifier that adds a help item preference value.

 Use `transformAnchorPreference` so that containers do not shadow entities they hold. Since the default value is an empty
 dictionary, this is also safe to use for non-container views.

 Note that during tests, it is possible that `namespace` is not installed, thus the need to conditionally apply the
 `matchedGeometryEffect` modifier.
 */
private struct HelpInfoViewTagModifier<ID: Hashable>: ViewModifier {
  let id: ID
  @Environment(\.helpInfoSpotlightAnimationNamespace) private var namespace

  func body(content: Content) -> some View {
    if let namespace = namespace {
      content
        .matchedGeometryEffect(id: id, in: namespace, properties: .frame, anchor: .center, isSource: true)
        .transformAnchorPreference(key: HelpInfoSpotlightOverlayPreferenceKey<ID>.self, value: .bounds) {
          $0[id] = $1
        }
    } else {
      content
        .transformAnchorPreference(key: HelpInfoSpotlightOverlayPreferenceKey<ID>.self, value: .bounds) {
          $0[id] = $1
        }
    }
  }
}

private enum HelpInfoSpotlightCoordinateSpace {
  // Shared coordinate space name used by spotlight sources and the container.
  static let name = "helpInfoSpotlightCoordinateSpace"
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

private struct HelpInfoSpotlightNamespaceEnvironmentKey: EnvironmentKey {
  fileprivate static var defaultValue: Namespace.ID? { nil }
}

extension EnvironmentValues {

  /// Custom EnvironmentValues property that provides the help spotlight animation namespace.
  fileprivate var helpInfoSpotlightAnimationNamespace: Namespace.ID? {
    get { self[HelpInfoSpotlightNamespaceEnvironmentKey.self] }
    set { self[HelpInfoSpotlightNamespaceEnvironmentKey.self] = newValue }
  }
}

extension View {

  fileprivate func helpInfoSpotlightAnimationNamespace(_ value: Namespace.ID) -> some View {
    environment(\.helpInfoSpotlightAnimationNamespace, value)
  }
}

#if DEBUG

struct TutorialSpotlightDemo: View {
  @Environment(\.colorScheme) var colorScheme

  enum Step: CaseIterable, HelpInfoProvider {
    case profile
    case travelPlanner
    case filters
    case budgetFilter
    case familyFilter
    case foodFilter
    case showSheet
    case checkout

    var title: LocalizedStringKey {
      switch self {
      case .profile: "Profile"
      case .travelPlanner: "Travel Planner"
      case .filters: "Filters"
      case .budgetFilter: "Budget"
      case .familyFilter: "Family"
      case .foodFilter: "Food"
      case .showSheet: "Plan Summary"
      case .checkout: "Checkout"
      }
    }

    var text: LocalizedStringKey {
      switch self {
      case .profile:
"""
Here the user quickly gets to their \(Image(systemName: "checkmark")) profile and account settings.
"""
      case .travelPlanner:
"""
This is a test. \
This is a test. \
This is a test. \
This is a test.
This is a test.
"""
      case .filters:
"""
This block manages filters.
It's usually the second step in onboarding.
"""
      case .budgetFilter:
"""
Apply the 'Budget' smart filter.
"""
      case .familyFilter:
"""
Apply the 'Family' smart filter. Do special processing when activated.
"""
      case .foodFilter:
"""
Apply the 'Food' smart filter. Nothing special.
"""
      case .showSheet:
"""
Show the plan summary.
"""
      case .checkout:
"""
The button completes the scenario. The final step may lead to payment or confirmation.
"""
      }
    }
  }

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
            .helpInfoViewTag(.filters)

          Button("Show Sheet") { showSheet.toggle() }
            .helpInfoViewTag(.showSheet)
        }
        .helpInfoViewTag(.travelPlanner)
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
        ToolbarItem(placement: .topBarLeading) {
          profileButton
            .helpInfoViewTag(.profile)
        }
        ToolbarItem(placement: .topBarTrailing) {
          Button {
            selection = .profile
          } label: {
            Image(systemName: "questionmark.circle")
          }
        }
      }
      .safeAreaInset(edge: .bottom) {
        checkoutButton
          .helpInfoViewTag(.checkout)
          .padding()
      }
    }
    .sheet(isPresented: $showSheet) {
      SheetSpotlightDemo()
    }
    .helpInfoSpotlightOverlay(selection: $selection, orderedIDs: Step.allCases, overlay: helpInfoOverlay)
  }

  private var profileButton: some View {
    Button {

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
          .helpInfoViewTag(.budgetFilter)
        chip("Family")
          .helpInfoViewTag(.familyFilter)
        chip("Food")
          .helpInfoViewTag(.foodFilter)
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
}

struct SheetSpotlightDemo: View {

  enum Step: CaseIterable, HelpInfoProvider {
    case title
    case action

    var title: LocalizedStringKey {
      switch self {
      case .title: "Sheet Header"
      case .action: "Primary Action"
      }
    }

    var text: LocalizedStringKey {
      switch self {
      case .title: "This title explains the purpose of the modal flow."
      case .action: "This button confirms the choice and closes the scenario."
      }
    }
  }

  @Environment(\.dismiss) private var dismiss
  @State private var selection: Step?

  var body: some View {
    NavigationStack {
      VStack(alignment: .leading, spacing: 24) {
        VStack(alignment: .leading, spacing: 12) {
          Text("Plan Summary")
            .font(.title2.bold())
            .helpInfoViewTag(.title)

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
        .helpInfoViewTag(.action)
      }
      .padding(24)
      .navigationTitle("Booking")
      .navigationBarTitleDisplayMode(.inline)
    }
    .presentationDetents([.medium, .large])
    .helpInfoSpotlightOverlay(selection: $selection, orderedIDs: Step.allCases, overlay: helpInfoOverlay)
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

// Extensions to support auto-completion of `Step` enum values.
extension View {
  fileprivate func helpInfoViewTag(_ id: TutorialSpotlightDemo.Step) -> some View { helpInfoViewTag(id: id) }
  fileprivate func helpInfoViewTag(_ id: SheetSpotlightDemo.Step) -> some View { helpInfoViewTag(id: id) }
}

@available(iOS 16.0)
#Preview {
  TutorialSpotlightDemo()
}

#endif // DEBUG
