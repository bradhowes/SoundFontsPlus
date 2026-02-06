// Copyright © 2025 Brad Howes. All rights reserved.

import AVFAudio
import BRHSplitView
import FeatureSupport
import Presets
import Settings
import SF2LibAU
import Sharing
import SoundFonts
import SwiftUI
import Tags
import ToolBar

public struct AUv3RootView: View {
  @Bindable private var store: StoreOf<AUv3Root>

  private let dividerBorderColor: Color = .splitViewHandleBackgroundColor
  private let dividerSpan: CGFloat = 2

  @Environment(\.scenePhase) var scenePhase

  public init(store: StoreOf<AUv3Root>) {
    self.store = store
    navigationBarTitleStyle()
  }

  public var body: some View {
    VStack(spacing: 0) {
      listViews
      controlViews
    }
    .padding(0)
    .environment(\.font, FeatureSupport.Font.body)
    .task {
      await store.send(.initialize).finish()
    }
    .sheets(store: $store)
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
   - returns: modified view
   */
  fileprivate func sheets(store: Bindable<StoreOf<AUv3Root>>) -> some View {
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
    let acd = Bundle.main.audioComponentDescription
    // swiftlint:disable:next force_try
    let audioUnit = try! SF2LibAU(componentDescription: acd)
    return AUv3RootView(store: AUv3Root.makeWithDependencies(audioUnit: audioUnit))
  }
}

#Preview {
  AUv3RootView.preview
}

#endif
