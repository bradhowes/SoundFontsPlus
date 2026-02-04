// Copyright © 2025 Brad Howes. All rights reserved.

import AppReview
import AUv3Controls
import BRHSplitView
import Changes
import DelayEffect
import FeatureSupport
import Keyboard
import Presets
import ReverbEffect
import Settings
import Sharing
import SoundFonts
import SwiftToasts
import SwiftUI
import Tags
import ToolBar
import Tutorial
import VolumeMonitor

public struct AppRootView: View {
  @Bindable private var store: StoreOf<AppRoot>

  private let dividerBorderColor: Color = .splitViewHandleBackgroundColor
  private let dividerSpan: CGFloat = 4
  @State private var isInputKeyboardVisible = false
  @State private var effectsOffset: CGFloat = 0.0

  @Shared(.effectsPanelVisible) private var effectsPanelVisible

  @Environment(\.scenePhase) var scenePhase
  @Environment(\.colorScheme) private var colorScheme
  @Environment(\.maxKeyboardPanelHeight) private var maxKeyboardPanelHeight
  @Environment(\.horizontalSizeClass) private var horizontalSizeClass
  @Environment(\.verticalSizeClass) private var verticalSizeClass

  private var showFakeKeyboard: Bool {
    horizontalSizeClass == .compact || verticalSizeClass == .compact
  }

  private var keyboardHeight: CGFloat {
    isInputKeyboardVisible
      ? 1.0
      : maxKeyboardPanelHeight * (verticalSizeClass == .compact ? 0.5 : 1.0)
  }

  private var theme: AUv3Controls.Theme {
    var theme = Theme(colorScheme: colorScheme)
    theme.controlForegroundColor = .mainAccentColor
    theme.textColor = colorScheme == .dark ? .mainAccentColor.mix(with: .black, by: 0.2) : .mainAccentColor.mix(with: .white, by: 0.2)
    theme.controlTrackStrokeStyle = StrokeStyle(lineWidth: 5, lineCap: .round)
    theme.controlValueStrokeStyle = StrokeStyle(lineWidth: 3, lineCap: .round)
    theme.toggleOnIndicatorSystemName = "arrowtriangle.down.fill"
    theme.toggleOffIndicatorSystemName = "arrowtriangle.down"
    theme.font = .effectsControl
    return theme
  }

  public init(store: StoreOf<AppRoot>) {
    self.store = store
    navigationBarTitleStyle()
  }

  public var body: some View {

    // let _ = Self._printChanges()
    VStack(spacing: 0) {
      listViews
      controlViews
    }
    .padding(0)
    .animation(.smooth, value: effectsPanelVisible)
    .animation(.smooth, value: isInputKeyboardVisible)
    .environment(\.auv3ControlsTheme, theme)
    .onChange(of: scenePhase) { _, newPhase in
      store.send(.scenePhaseChanged(newPhase))
    }
    .task {
      await store.send(.initialize).finish()
    }
#if os(iOS)
    .onReceive(keyboardVisibilityPublisher) { state in
      isInputKeyboardVisible = state
      // If restoring display of the virtual music keyboard, scroll to the active preset
      // since it could become hidden by the keyboard.
      if !state {
        store.scope(state: \.presetsList, action: \.presetsList).send(.showActivePreset)
      }
    }
#endif // os(iOS)
    .sheets(
      store: $store,
      horizontalSizeClass: horizontalSizeClass,
      verticalSizeClass: verticalSizeClass
    )
    .appReview(store: store.scope(state: \.appReview, action: \.appReview))
    .toast(item: $store.toastState, alignment: .top) { reason in
      volumeMonitorToast(reason)
    }
    .toastStyle(.plain)
    .alert($store.scope(state: \.destination?.alert, action: \.destination.alert))
  }

  private func volumeMonitorToast(_ reason: VolumeMonitor.Reason) -> Toast {
    switch reason {
    case .volumeLevelIsZero:
      Toast(role: .failure, duration: .indefinite) {
        Label {
          Text("Volume is muted.")
            .font(.toastLabel)
            .foregroundStyle(.teal)
        } icon: {
          Image(systemName: "speaker.slash")
        }
      }
    case .noActivePreset:
      Toast(role: .failure, duration: .indefinite) {
        Label {
          Text("No preset selected.")
            .font(.toastLabel)
            .foregroundStyle(.teal)
        } icon: {
          Image(systemName: "speaker.slash")
        }
      }
    }
  }
}

#if os(iOS)
extension AppRootView: KeyboardVisibilityPublisher {}
#endif

extension AppRootView {

  fileprivate var listViews: some View {
    SplitView(
      store: store.scope(state: \.fontsAndPresetsSplit, action: \.fontsAndPresetsSplit),
      primary: {
        fontsAndTags
      },
      divider: {
        handleDivider
      },
      secondary: {
        PresetsListView(store: store.scope(state: \.presetsList, action: \.presetsList))
      }
    ).splitViewConfiguration(
      .init(
        orientation: .horizontal,
        draggableRange: 0.35...0.7
      )
    )
  }

  fileprivate var fontsAndTags: some View {
    SplitView(
      store: store.scope(state: \.fontsAndTagsSplit, action: \.fontsAndTagsSplit),
      primary: {
        SoundFontsListView(store: store.scope(state: \.soundFontsList, action: \.soundFontsList))
      },
      divider: {
        handleDivider
      },
      secondary: {
        TagsListView(store: store.scope(state: \.tagsList, action: \.tagsList))
      }
    ).splitViewConfiguration(
      .init(
        orientation: .vertical,
        draggableRange: 0.15...0.85,
        dragToHidePanes: .secondary,
        doubleClickToClose: .secondary
      )
    )
  }

  fileprivate var handleDivider: some View {
    HandleDivider(
      dividerColor: .splitViewHandleBackgroundColor,
      handleColor: .splitViewHandleBackgroundColor,
      dotColor: .mainAccentColor,
      handleLength: 48,
      handleWidth: 8.0,
      paddingInsets: 4.0
    )
  }

  fileprivate var controlViews: some View {
    VStack(spacing: 0) {
      dividerBorderColor
        .frame(height: dividerSpan)
      effectsView
        .knobValueEditor()
        .auv3ControlsTheme(theme)
      ToolBarView(store: store.scope(state: \.toolBar, action: \.toolBar))
      dividerBorderColor
        .frame(height: dividerSpan)
      keyboardView
    }
  }

  fileprivate var effectsView: some View {
    let effectsHeight = 110.0
    let viewHeight = effectsHeight + dividerSpan * 4

    return VStack(alignment: .leading, spacing: 0) {
      ScrollView(.horizontal) {
        HStack(spacing: 0) {
          ReverbEffectView(store: store.scope(state: \.reverb, action: \.reverb))
          dividerBorderColor
            .frame(width: dividerSpan)
          DelayEffectView(store: store.scope(state: \.delay, action: \.delay))
        }
      }
      .onScrollGeometryChange(for: CGFloat.self) { geometry in
        max(0.0, (geometry.visibleRect.width - geometry.contentSize.width) / 2)
      } action: { _, newValue in
        effectsOffset = newValue
      }
      .scrollDisabled(effectsOffset > 0)
      dividerBorderColor
        .frame(height: dividerSpan)
    }
    .frame(height: effectsPanelVisible ? viewHeight : 0.0)
    .frame(maxWidth: .infinity)
    .offset(y: effectsPanelVisible ? 0.0 : viewHeight / 2 + dividerSpan * 2)
  }

  fileprivate var keyboardView: some View {
    KeyboardView(store: store.scope(state: \.keyboard, action: \.keyboard))
      .frame(height: keyboardHeight)
      .opacity(isInputKeyboardVisible ? 0.0 : 1.0)
  }
}

extension View {

  /// Swift compiler struggles to deal with too many `.sheet` definitions, hence the explosion of custom `View` methods
  /// to isolate each one in its own method.

  /**
   Custom `View` modifier that generates all of the optional sheets that can be created in the feature.
  
   - parameter store: the `Root` store which will be scoped to a child feature for displaying
   - parameter horizontalSizeClass: indicator of the horizontal size of the view
   - parameter verticalSizeClass: indicator of the vertical size of the view
   - returns: modified view
   */
  fileprivate func sheets(
    store: Bindable<StoreOf<AppRoot>>,
    horizontalSizeClass: UserInterfaceSizeClass?,
    verticalSizeClass: UserInterfaceSizeClass?
  ) -> some View {
    self
      .changesSheet(store.scope(state: \.destination?.changes, action: \.destination.changes))
      .presetEditorSheet(store.scope(state: \.destination?.presetEditor, action: \.destination.presetEditor))
      .settingsSheet(store.scope(state: \.destination?.settings, action: \.destination.settings), showFakeKeyboard: false)
      .soundFontEditorSheet(store.scope(state: \.destination?.soundFontEditor, action: \.destination.soundFontEditor))
      .tagsEditorSheet(store.scope(state: \.destination?.tagsEditor, action: \.destination.tagsEditor))
      .tutorialSheet(store.scope(state: \.destination?.tutorial, action: \.destination.tutorial))
  }

  fileprivate func presetEditorSheet(_ store: Bindable<StoreOf<AppRoot>>) -> some View {
    self
      .sheet(item: store.scope(state: \.destination?.presetEditor, action: \.destination.presetEditor)) {
        PresetEditorView(store: $0)
      }
  }

  fileprivate func settingsSheet(_ store: Bindable<StoreOf<AppRoot>>, showFakeKeyboard: Bool) -> some View {
    self
      .sheet(item: store.scope(state: \.destination?.settings, action: \.destination.settings)) {
        SettingsView(store: $0, showFakeKeyboard: showFakeKeyboard)
      }
  }

  fileprivate func soundFontEditorSheet(_ store: Bindable<StoreOf<AppRoot>>) -> some View {
    self
      .sheet(item: store.scope(state: \.destination?.soundFontEditor, action: \.destination.soundFontEditor)) {
        SoundFontEditorView(store: $0)
      }
  }

  fileprivate func tagsEditorSheet(_ store: Bindable<StoreOf<AppRoot>>) -> some View {
    self
      .sheet(item: store.scope(state: \.destination?.tagsEditor, action: \.destination.tagsEditor)) { child in
        NavigationStack {
          TagsEditorView(store: child)
        }
      }
  }

#if os(iOS)
  fileprivate func tutorialSheet(_ store: Bindable<StoreOf<AppRoot>>) -> some View {
    self
      .sheet(item: store.scope(state: \.destination?.tutorial, action: \.destination.tutorial)) { child in
        NavigationStack {
          TutorialView(store: child)
        }
      }
  }
#endif // os(iOS)
}

#if DEBUG

extension AppRootView {

  static var preview: some View {
    AppRootView(store: AppRoot.makeWithDependencies())
  }
}

#Preview {
  AppRootView.preview
}

#endif
