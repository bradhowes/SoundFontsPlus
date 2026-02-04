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

public struct AUv3RootView: View {
  @Bindable private var store: StoreOf<AppRoot>

  private let appPanelBackground = Color.black
  private let dividerBorderColor: Color = Color.gray.mix(with: .black, by: 0.7)
  private let dividerSpan: CGFloat = 4
  @State private var isInputKeyboardVisible = false
  @State private var effectsOffset: CGFloat = 0.0

  @Shared(.effectsPanelVisible) private var effectsPanelVisible

  @Environment(\.scenePhase) var scenePhase
  @Environment(\.colorScheme) private var colorScheme
  @Environment(\.horizontalSizeClass) private var horizontalSizeClass
  @Environment(\.verticalSizeClass) private var verticalSizeClass

  private var theme: Theme {
    var theme = Theme(colorScheme: colorScheme)
    theme.controlForegroundColor = .teal
    theme.textColor = .teal.mix(with: .black, by: 0.2)
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
    .environment(\.font, FeatureSupport.Font.body)
    .environment(\.auv3ControlsTheme, theme)
    .environment(\.appPanelBackground, appPanelBackground)
    .onChange(of: scenePhase) { _, newPhase in
      store.send(.scenePhaseChanged(newPhase))
    }
    .task {
      await store.send(.initialize).finish()
    }
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

extension AUv3RootView {

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
      dividerColor: dividerBorderColor,
      handleColor: .black,
      dotColor: .accentColor,
      handleLength: 48,
      handleWidth: 8.0,
      paddingInsets: 4.0
    )
  }

  fileprivate var controlViews: some View {
    VStack(spacing: 0) {
      dividerBorderColor
        .frame(height: dividerSpan)
      ToolBarView(store: store.scope(state: \.toolBar, action: \.toolBar))
    }
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
      .presetEditorSheet(store.scope(state: \.destination?.presetEditor, action: \.destination.presetEditor))
      .settingsSheet(store.scope(state: \.destination?.settings, action: \.destination.settings), showFakeKeyboard: false)
      .soundFontEditorSheet(store.scope(state: \.destination?.soundFontEditor, action: \.destination.soundFontEditor))
      .tagsEditorSheet(store.scope(state: \.destination?.tagsEditor, action: \.destination.tagsEditor))
  }
}

#if DEBUG

extension AUv3RootView {

  static var preview: some View {
    return ZStack {
      Color.black
        .ignoresSafeArea(edges: .all)
      AUv3RootView(store: AppRoot.makeWithDependencies())
    }
  }
}

#Preview {
  AUv3RootView.preview
}

#endif
