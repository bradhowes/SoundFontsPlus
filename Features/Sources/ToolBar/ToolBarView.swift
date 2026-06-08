// Copyright © 2025 Brad Howes. All rights reserved.

import FeatureSupport
import Keyboard
import MIDITrafficIndicator
import SwiftUI

public struct ToolBarView: View {
  private var store: StoreOf<ToolBar>
  @Shared(.showActiveVoiceCount) private var showActiveVoiceCount
  @Shared(.showMIDITrafficIndicator) private var showMIDITrafficIndicator
  @Shared(.favoriteSymbolName) private var favoriteSymbolName
  @Shared(.starFavoriteNames) private var starFavoriteNames
  @Environment(\.colorScheme) private var colorScheme
  @Environment(\.controlSpacing) var controlSpacing

  private let minWIdthNoMoreButtons: CGFloat = 400
  private let rowHeight: CGFloat = 28
  private let isAUv3: Bool
  private var isApp: Bool { !isAUv3 }

  private var showingPresetSymbol: Bool { starFavoriteNames && store.preset?.kind == .favorite && store.temporaryStatus == nil }
  private var statusTextValue: String { store.temporaryStatus?.text ?? store.preset?.displayName ?? "—" }
  private var statusTextColor: Color {
    (store.preset?.kind == .favorite || store.temporaryStatus != nil) ? .alternateAccentColor : .mainAccentColor
  }

  private var height: CGFloat { store.showMoreButtons ? rowHeight * 2 + controlSpacing - 5 : rowHeight }

  @State private var animationState: AnimationState = .init()

  public init(store: StoreOf<ToolBar>, isAUv3: Bool) {
    self.store = store
    self.isAUv3 = isAUv3
  }

  public var body: some View {
    GeometryReader { geometryProxy in
      if geometryProxy.size.width < minWIdthNoMoreButtons {
        compactBar
      } else {
        fullBar
      }
    }
    .imageScale(.large)
    .frame(minHeight: height)
    .frame(height: height)
    .padding([.top, .bottom], controlSpacing)
    .background(.windowBackground)
    .animation(.smooth, value: store.showMoreButtons)
    .animation(.smooth, value: height)
    .animation(.smooth, value: store.activeVoiceCount)
    .fileImporterFeature(store.scope(state: \.fileImporter, action: \.fileImporter))
  }
}

extension ToolBarView {

  private var fullBar: some View {
    HStack(alignment: .center, spacing: controlSpacing) {
      if isApp {
        fullBarApp
      } else {
        fullBarAUv3
      }
    }
    .task {
      await store.send(.initialize(false)).finish()
    }
  }

  @ViewBuilder
  private var fullBarApp: some View {
    addSoundFontButton
    tagsButton
    effectsButton
    status
    shiftDownButton
    slidingKeyboardButton
    shiftUpButton
    editVisibilityButton
    settingsButton
    helpButton
  }

  @ViewBuilder
  private var fullBarAUv3: some View {
    tagsButton
    status
    editVisibilityButton
    settingsButton
    helpButton
  }

  private var compactBar: some View {
    VStack(alignment: .center, spacing: controlSpacing) {
      compactBarRow1
      if store.showMoreButtons {
        compactBarRow2
          .transition(.move(edge: .bottom))
      }
    }
    .fixedSize(horizontal: false, vertical: true)
    .padding(0)
    .task {
      await store.send(.initialize(true)).finish()
    }
  }

  private var compactBarRow1: some View {
    HStack(alignment: .center, spacing: controlSpacing) {
      addSoundFontButton
      tagsButton
      effectsButton
      status
      helpButton
      moreButton
    }
    .padding([.horizontal], controlSpacing)
  }

  private var compactBarRow2: some View {
    HStack(alignment: .center, spacing: controlSpacing) {
      Spacer()
      shiftDownButton
      slidingKeyboardButton
      shiftUpButton
      editVisibilityButton
      settingsButton
    }
    .padding([.horizontal], controlSpacing)
    .animation(.smooth, value: store.lowestKey)
    .animation(.smooth, value: store.highestKey)
  }

  @ViewBuilder
  private var compactBarAUv3: some View {
    tagsButton
    editVisibilityButton
    settingsButton
    status
  }

  private var status: some View {
    ZStack(alignment: .leading) {
      if showMIDITrafficIndicator {
        MIDITrafficIndicatorView(store: store.scope(state: \.midiTrafficIndicator, action: \.midiTrafficIndicator))
          .zIndex(-99)
      }
      HStack {
        if showActiveVoiceCount {
          voiceCountIndicator
        }
        statusText
          .helpInfoViewTag(.statusWindow)
      }
    }
    .animation(.smooth, value: showActiveVoiceCount)
  }

  private var voiceCountIndicator: some View {
    Text(store.activeVoiceCount > 0 ? "\(store.activeVoiceCount)" : "")
      .font(.activeVoiceCount)
      .indicator(.activeNoIndicator)
      .contentTransition(.interpolate)
      .frame(width: 24, alignment: .center)
  }

  private var statusText: some View {
    HStack {
      if showingPresetSymbol {
        Image(systemName: favoriteSymbolName)
      }
      Text(statusTextValue)
      Spacer()
    }
    .font(.status)
    .lineLimit(1)
    .truncationMode(.tail)
    .foregroundStyle(statusTextColor)
    .contentTransition(.interpolate)
    .animation(.smooth, value: statusTextValue)
    .contentShape(Rectangle())
    .onTapGesture(count: 2) { store.send(.statusTextTapped(count: 2)) }
    .onTapGesture(count: 1) { store.send(.statusTextTapped(count: 1)) }
  }

  private var addSoundFontButton: some View {
    Button {
      store.send(.addSoundFontButtonTapped)
    } label: {
      Image(systemName: .addSoundFontButtonImageName)
        .tint(.mainAccentColor)
    }
    .helpInfoViewTag(RootHelpInfo.addButton)
  }

  private var editVisibilityButton: some View {
    Button {
      store.send(.presetsVisibilityButtonTapped)
    } label: {
      Image(systemName: .presetsVisibilityButtonImageName)
        .tint(if: store.editingPresetVisibility)
    }
    .helpInfoViewTag(.editVisibilityButton)
  }

  private var effectsButton: some View {
    print("effectsButton - \(store.effectsPanelVisible)")
    return Button {
      store.send(.effectsVisibilityButtonTapped)
    } label: {
      Image(systemName: .effectsButtonImageName)
        .tint(if: store.effectsPanelVisible)
    }
    .helpInfoViewTag(.effectsButton)
  }

  private var helpButton: some View {
    Button {
      store.send(.helpInfoButtonTapped)
    } label: {
      Image(systemName: .helpButtonImageName)
        .tint(Color.mainAccentColor)
    }
  }

  private var moreButton: some View {
    Button {
      store.send(.showMoreButtonTapped)
    } label: {
      Image(systemName: .moreButtonImageName)
        .tint(if: store.showMoreButtons)
        .keyframeAnimator(initialValue: animationState, trigger: store.showMoreButtons) { content, value in
          content
            .rotationEffect(value.angle)
        } keyframes: { _ in
          KeyframeTrack(\.angle) {
            CubicKeyframe(.degrees(store.showMoreButtons ? -90 : 0), duration: 0.28)
          }
        }
        .animation(.smooth, value: store.showMoreButtons)
    }
    .helpInfoViewTag(.moreButton)
  }

  private var settingsButton: some View {
    Button {
      store.send(.settingsButtonTapped)
    } label: {
      Image(systemName: .settingsButtonImageName)
        .tint(.mainAccentColor)
    }
    .helpInfoViewTag(.settingsButton)
  }

  private var shiftDownButton: some View {
    Button {
      store.send(.shiftKeyboardDownButtonTapped)
    } label: {
      Text(.shiftKeyboardLeftIndicator + store.lowestKey.label)
        .tint(.mainAccentColor)
    }
    .disabled(self.store.lowestKey.midiNoteValue == Note.midiRange.lowerBound)
    .helpInfoViewTag(.shiftDownButton)
  }

  private var shiftUpButton: some View {
    Button {
      store.send(.shiftKeyboardUpButtonTapped)
    } label: {
      Text(store.highestKey.label + .shiftKeyboardRightIndicator)
        .tint(.mainAccentColor)
    }
    .disabled(self.store.highestKey.midiNoteValue == Note.midiRange.upperBound)
    .helpInfoViewTag(.shiftUpButton)
  }

  private var slidingKeyboardButton: some View {
    Button {
      store.send(.slidingKeyboardButtonTapped)
    } label: {
      Image(
        systemName: store.keyboardSlides
        ? .slidingKeyboardButtonImageName
        : .fixedKeyboardButtonImageName
      )
      .tint(if: store.keyboardSlides)
    }
    .helpInfoViewTag(.slideToggle)
  }

 private var tagsButton: some View {
    Button {
      store.send(.tagsListVisibilityButtonTapped)
    } label: {
      Image(systemName: .tagsListButtonImageName)
        .tint(if: store.tagsListVisible)
    }
    .helpInfoViewTag(.tagsButton)
  }
}

private struct AnimationState {
  var angle: Angle = .zero
}

#if DEBUG

extension ToolBarView {
  static func preview() -> some View {

    struct Preview: View {
      let store = Store(
        initialState: .init(
          preset: Preset(
            id: 0,
            index: 0,
            bank: 1,
            program: 1,
            originalName: "Foo",
            soundFontId: 0,
            displayName: "Foo"
          )
        )
      ) {
        ToolBar()
      }

      var body: some View {
        VStack(spacing: 0) {
          ToolBarView(store: store, isAUv3: false)
          KeyboardView(store: Store(initialState: .init()) { Keyboard() })
        }
        .animation(.smooth, value: store.state.showMoreButtons)
      }
    }

    return Preview()
  }
}

#Preview {
  ToolBarView.preview()
}

#endif // DEBUG
