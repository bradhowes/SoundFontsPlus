// Copyright © 2025 Brad Howes. All rights reserved.

import AppReview
import AUv3Controls
import BRHSplitView
import Changes
import DelayEffect
import FeatureSupport
import Keyboard
import MorkAndMIDI
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
  private let dividerSpan: CGFloat = 2
  private let effectsHeight: CGFloat = 110.0
  private var effectsViewHeight: CGFloat { effectsHeight + dividerSpan * 4 }

  @State private var isTextInputKeyboardVisible = false
  @State private var effectsOffset: CGFloat = 0.0

  // @Shared(.effectsPanelVisible) private var effectsPanelVisible

  @Environment(\.scenePhase) var scenePhase
  @Environment(\.colorScheme) private var colorScheme
  @Environment(\.maxKeyboardPanelHeight) private var maxKeyboardPanelHeight
  @Environment(\.horizontalSizeClass) private var horizontalSizeClass
  @Environment(\.verticalSizeClass) private var verticalSizeClass

  private var showFakeKeyboard: Bool {
    horizontalSizeClass == .compact || verticalSizeClass == .compact
  }

  private var keyboardHeight: CGFloat {
    isTextInputKeyboardVisible
      ? 1.0
      : maxKeyboardPanelHeight * (verticalSizeClass == .compact ? 0.5 : 1.0)
  }

  private var theme: AUv3Controls.Theme {
    var theme = Theme(colorScheme: colorScheme)
    theme.controlForegroundColor = .mainAccentColor
    theme.textColor = colorScheme == .dark ? .mainAccentColor.mix(with: .black, by: 0.2) : .mainAccentColor.mix(with: .white, by: 0.2)
    theme.controlTrackStrokeStyle = StrokeStyle(lineWidth: 5, lineCap: .round)
    theme.controlValueStrokeStyle = StrokeStyle(lineWidth: 3, lineCap: .round)
    theme.toggleOnIndicatorSystemName = .effectsToggleOnButtonImageName
    theme.toggleOffIndicatorSystemName = .effectsToggleOffButtonImageName
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
    .animation(.smooth, value: store.effectsPanelVisible)
    .animation(.smooth, value: isTextInputKeyboardVisible)
    .environment(\.auv3ControlsTheme, theme)
    .onChange(of: scenePhase) { _, newPhase in
      store.send(.scenePhaseChanged(newPhase))
    }
    .task {
      await store.send(.initialize).finish()
    }
#if os(iOS)
    .onReceive(keyboardVisibilityPublisher) { state in
      isTextInputKeyboardVisible = state
      // If restoring display after showing the iOS input keyboard, scroll to the active preset since it may have become hidden
      // by the geometry changes when hiding the music keyboard.
      if !state {
        store.scope(state: \.presetsList, action: \.presetsList).send(.showPresetDelayed(store.presetsList.activePresetId ?? -1))
      }
    }
#endif // os(iOS)
    .sheets(store: $store, isCompact: showFakeKeyboard)
    .appReview(store: store.scope(state: \.appReview, action: \.appReview))
    .toast(item: $store.toastState, alignment: .top) { reason in
      volumeMonitorToast(reason)
    }
    .toastStyle(.plain)
    .alert($store.scope(state: \.destination?.alert, action: \.destination.alert))
    .helpInfoSpotlightOverlay(
      selection: $store.helpInfoSelection,
      orderedIDs: HelpInfo.allCases
    ) { id, actions in
      spotlightCard(for: id, actions: actions)
    }
  }

  private func spotlightCard(
    for helpItem: HelpInfo,
    actions: HelpInfoSpotlightOverlayActions
  ) -> some View {
    VStack(spacing: 8) {
      HelpInfoLayout(spacing: 16) {
        Text(helpItem.title)
          .font(.title3.weight(.bold))
        Text(helpItem.text)
          .font(.footnote)
      }
      .overlay(alignment: .topTrailing) {
        Button {
          actions.dismiss()
        } label: {
          Image(systemName: .cancelButtonImageName)
        }
        .tint(.mainAccentColor)
      }
      HStack(spacing: 24) {
        Button {
          actions.previous()
        } label: {
          Image(systemName: .helpPreviousItemButtonImageName)
        }
        .tint(.mainAccentColor)
        Button {
          actions.next()
        } label: {
          Image(systemName: .helpNextItemButtonImageName)
        }
        .tint(.mainAccentColor)
      }
      .fontWeight(.semibold)
    }
    .padding(20)
    .background {
      RoundedRectangle(cornerRadius: 28)
        .fill(colorScheme == .dark ? Color.black : Color.white)
    }
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
          Image(systemName: .noAudioVolumeImageName)
        }
      }
    case .noActivePreset:
      Toast(role: .failure, duration: .indefinite) {
        Label {
          Text("No preset selected.")
            .font(.toastLabel)
            .foregroundStyle(.teal)
        } icon: {
          Image(systemName: .noAudioVolumeImageName)
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
          .helpInfoViewTag(.fontsPresetsDivider)
      },
      secondary: {
        PresetsListView(store: store.scope(state: \.presetsList, action: \.presetsList))
      }
    ).splitViewConfiguration(
      .init(
        orientation: .horizontal,
        draggableRange: .fixedLength(lowerSpan: 140.0, upperSpan: 140.0),
        visibleDividerSpan: dividerSpan
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
          .helpInfoViewTag(.fontsTagsDivider)
      },
      secondary: {
        TagsListView(store: store.scope(state: \.tagsList, action: \.tagsList))
          .helpInfoViewTag(.tagsList)
      }
    ).splitViewConfiguration(
      .init(
        orientation: .vertical,
        draggableRange: .fixedLength(lowerSpan: 100.0, upperSpan: 100.0),
        dragToHidePanes: .secondary,
        doubleClickToClose: .secondary,
        visibleDividerSpan: dividerSpan
      )
    )
  }

  fileprivate var handleDivider: some View {
    HandleDivider(
      dividerColor: dividerBorderColor,
      handleColor: dividerBorderColor,
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
        .helpInfoViewTag(.effectsPanel)
      ToolBarView(store: store.scope(state: \.toolBar, action: \.toolBar), isAUv3: false)
      dividerBorderColor
        .frame(height: dividerSpan)
      if !isTextInputKeyboardVisible {
        KeyboardView(store: store.scope(state: \.keyboard, action: \.keyboard))
          .transition(.scale.combined(with: .move(edge: .bottom)))
      }
    }
  }

  fileprivate var effectsView: some View {
    VStack(alignment: .leading, spacing: 0) {
      ScrollView(.horizontal) {
        HStack(spacing: 0) {
          ReverbEffectView(store: store.scope(state: \.reverbEffect, action: \.reverbEffect))
          dividerBorderColor
            .frame(width: dividerSpan)
          DelayEffectView(store: store.scope(state: \.delayEffect, action: \.delayEffect))
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
    .frame(height: store.effectsPanelVisible ? effectsViewHeight : 0.0)
    .frame(maxWidth: .infinity)
    .offset(y: store.effectsPanelVisible ? 0.0 : effectsViewHeight / 2 + dividerSpan * 2)
    .opacity(store.effectsPanelVisible ? 1.0 : 0.0)
  }
}

extension View {

  /// Swift compiler struggles to deal with too many `.sheet` definitions, hence the explosion of custom `View` methods
  /// to isolate each one in its own method.

  /**
   Custom `View` modifier that generates all of the optional sheets that can be created in the feature.

   - parameter store: the `Root` store which will be scoped to a child feature for displaying
   - returns: modified view
   */
  fileprivate func sheets(store: Bindable<StoreOf<AppRoot>>, isCompact: Bool) -> some View {
    self
      .changesSheet(store.scope(state: \.destination?.changes, action: \.destination.changes))
      .presetEditorSheet(store.scope(state: \.destination?.presetEditor, action: \.destination.presetEditor))
      .settingsSheet(
        store.scope(state: \.destination?.settings, action: \.destination.settings),
        showFakeKeyboard: isCompact,
        isAUv3: false
      )
      .soundFontEditorSheet(store.scope(state: \.destination?.soundFontEditor, action: \.destination.soundFontEditor))
      .tagsEditorSheet(store.scope(state: \.destination?.tagsEditor, action: \.destination.tagsEditor))
      .tutorialSheet(store.scope(state: \.destination?.tutorial, action: \.destination.tutorial))
  }
}

#if DEBUG

extension AppRootView {

  static var preview: some View {
    @Shared(.colorSchemeBehavior) var colorSchemeBehavior

    return ZStack {
      colorSchemeBehavior.rootBackgroundColor
        .ignoresSafeArea()
      AppRootView(store: StoreOf<AppRoot>(initialState: AppRoot.State()) { AppRoot() })
    }
    .tint(.mainAccentColor)
    .environment(\.font, FeatureSupport.Font.body)
    .useColorScheme()
  }
}

#Preview {
  // swiftlint:disable:next redundant_discardable_let
  let _ = prepareDependencies {
    installApplicationFont()
    @Shared(.isAUv3) var isAUv3 = false

    // swiftlint:disable:next force_try
    $0.defaultDatabase = try! appDatabase()
    try? $0.fileManager.createDirectory($0.fileManager.fontFilesDirectory())

    @Shared(.midiInputPortId) var midiInputPortId
    @Shared(.midi) var midi = MIDI(clientName: "Test", uniqueId: Int32(midiInputPortId), midiProto: .v1_0)
  }
  AppRootView.preview
}

#endif // DEBUG
