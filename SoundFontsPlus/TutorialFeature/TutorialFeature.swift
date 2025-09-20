import ComposableArchitecture
import Sharing
import SwiftUI

@Reducer
public struct TutorialFeature {

  public enum Page: Int, CaseIterable {
    case intro = 1
    case fonts
    case presets
    case favorites
    case tags
    case toolBar1
    case toolBar2
    case reverb
    case delay
    case settings
    case last

    var prev: Page { .init(rawValue: self.rawValue - 1) ?? .intro }
    var next: Page { .init(rawValue: self.rawValue + 1) ?? .last }
  }

  @ObservableState
  public struct State: Equatable {
    var page: Page

    public init(page: Page = .favorites) {
      self.page = page
    }
  }

  public enum Action: BindableAction {
    case binding(BindingAction<State>)
    case dismissButtonTapped
    case next
    case page(Page)
    case prev
  }

  public static var shouldShow: Bool {
#if ALWAYS_SHOW_TUTORIAL
    return true
#else
    @Shared(.showedTutorial) var showedTutorial
    return !showedTutorial
#endif
  }

  public var body: some ReducerOf<Self> {
    BindingReducer()

    Reduce { state, action in
      switch action {

      case .binding:
        return .none

      case .dismissButtonTapped:
        @Dependency(\.dismiss) var dismiss
        return .run { _ in await dismiss() }

      case .next:
        state.page = state.page.next
        return .none

      case .page(let value):
        state.page = value
        return .none

      case .prev:
        state.page = state.page.prev
        return .none
      }
    }
  }
}

public struct TutorialFeatureView: View {
  @State private var store: StoreOf<TutorialFeature>
  let bottomSpacerMinLength: CGFloat = 24.0
  let sideTapRegionWidth: CGFloat = 24.0

  public init(store: StoreOf<TutorialFeature>) {
    self.store = store
  }

  public var body: some View {
    ZStack(alignment: .top) {
      TabView(selection: $store.page) {
        ForEach(TutorialFeature.Page.allCases, id: \.self) { page in
          Tab(value: page) {
            switch page {
            case .intro: intro
            case .fonts: fonts
            case .presets: presets
            case .favorites: favorites
            case .tags: tags
            case .toolBar1: toolBar1
            case .toolBar2: toolBar2
            case .reverb: reverb
            case .delay: delay
            case .settings: settings
            case .last: last
            }
          }
        }
      }
      .tabViewStyle(.page)
      .indexViewStyle(.page(backgroundDisplayMode: .always))
      .animation(.easeInOut(duration: 1.0), value: store.page)
      .transition(.slide)
      .padding([.leading, .trailing], 16)
      HStack {
        Rectangle()
          .fill(.clear)
          .frame(width: sideTapRegionWidth)
          .frame(maxHeight: .infinity)
          .contentShape(Rectangle())
          .onTapGesture {
            store.send(.prev)
          }
        Spacer()
        Rectangle()
          .fill(.clear)
          .frame(width: sideTapRegionWidth)
          .frame(maxHeight: .infinity)
          .contentShape(Rectangle())
          .onTapGesture {
            store.send(.next)
          }
      }
    }
    .toolbar {
      ToolbarItem(placement: .automatic) {
        Button("Done") { store.send(.dismissButtonTapped, animation: .default) }
      }
    }
  }
}

extension TutorialFeatureView {

  private func page(
    title: LocalizedStringKey,
    gist: LocalizedStringKey,
    @ViewBuilder rest: () -> some View
  ) -> some View {
    VStack(spacing: 18) {
      Text(title)
        .font(.title)
        .foregroundStyle(.orange)
      Text(gist)
        .font(.tutorialGist)
      rest()
      bottomSpacer
    }
    .font(.tutorialBody)
    .foregroundStyle(.teal)
  }

  private var bottomSpacer: some View {
    Spacer(minLength: bottomSpacerMinLength)
  }
}

extension TutorialFeatureView {

  private var intro: some View {
    page(
      title: "Welcome to SoundFonts+",
      gist:
"""
This brief tutorial will introduce you to the various parts of the app.

The tutorial will not appear upon future launches of the app, but you can always view it again via the \
\(Image(systemName: .settingsButtonImageName)) Settings panel.
"""
    ) {
      Text("Swipe left or tap along the right edge of the screen to continue.")
        .italic(true)
    }
  }

  private var fonts: some View {
    page(
      title: "Fonts",
      gist:
"""
The panel on the left-hand side shows names of the installed soundfont files.
"""
    ) {
      HStack(alignment: .top) {
        Image("FontsList")
          .resizable()
          .scaledToFit()
          .frame(width: 140)
        VStack(alignment: .leading, spacing: 24) {
          Grid(verticalSpacing: 12) {
            GridRow {
              Text("•")
              Text("Tap to activate and view the presets")
                .gridColumnAlignment(.leading)
            }
            GridRow {
              Text("•")
              Text("Long-tap to show editor panel")
                .gridColumnAlignment(.leading)
            }
            Text("Swipe Actions")
              .foregroundStyle(.orange)
            GridRow {
              Image(systemName: "pencil")
              Text("Edit name and tags")
                .gridColumnAlignment(.leading)
            }
            GridRow {
              Image(systemName: "trash")
                .foregroundStyle(.red)
              Text("Remove from device")
                .gridColumnAlignment(.leading)
            }
          }
        }
      }
      Text(
      """
Tap the \(Image(systemName: .addSoundFontButtonImageName)) toolbar button \
to add new files from iCloud or an external disk.
"""
      )
    }
  }

  private var presets: some View {
    @Shared(.favoriteSymbolName) var symbolName
    return page(
      title: "Presets",
      gist:
"""
The list to the right of the fonts list shows the visible presets in the selected font file.
"""
    ) {
      HStack(alignment: .top) {
        Image("PresetsList")
          .resizable()
          .scaledToFit()
          .frame(width: 220)
        VStack(alignment: .leading, spacing: 24) {
          Grid(verticalSpacing: 12) {
            GridRow {
              Text("•")
              Text("Tap to activate")
                .gridColumnAlignment(.leading)
            }
            GridRow {
              Text("•")
              Text("Long-tap to edit")
                .gridColumnAlignment(.leading)
            }
          }
        }
      }
      Text("Swipe Actions")
        .foregroundStyle(.orange)
      HStack(spacing: 18) {
        Grid {
          GridRow {
            Image(systemName: "pencil")
            Text("Edit preset")
              .gridColumnAlignment(.leading)
          }
          GridRow {
            Image(systemName: "star")
              .foregroundStyle(.orange)
            Text("Create favorite")
              .gridColumnAlignment(.leading)
          }
        }
        Grid {
          GridRow {
            Image(systemName: "eye.slash")
              .foregroundStyle(.gray)
            Text("Hide preset")
              .gridColumnAlignment(.leading)
          }
          GridRow {
            Image(systemName: "trash")
              .foregroundStyle(.red)
            Text("Remove favorite")
          }
        }
      }
      Text(
"""
Favorites you create will appear in gold and are prefixed with a \(Image(systemName: symbolName)) \
symbol (configurable). Next page talks more about them.
"""
      )
    }
  }

  private var favorites: some View {
    page(
      title: "Favorites",
      gist:
"""
Preset copies are known as \"favorites\". \
They provide a way to highlight a preset and to customize with your own settings.
"""
    ) {
      VStack(spacing: 18) {
        Image("PresetsList")
          .resizable()
          .scaledToFit()
          .frame(width: 220)
        Text(
"""
A preset can have multiple copies, each with their own name and settings. \
They normally appear below the original preset, but you can change this in the \
\(Image(systemName: .settingsButtonImageName)) Settings panel.
"""
        )
      }
    }
  }

  private var tags: some View {
    page(
      title: "Tags",
      gist:
"""
Tags help organize your font collection as it grows. \
They allow you to quickly change which fonts are visible.
"""
    ) {
      HStack(alignment: .top) {
        Image("TagsList")
          .resizable()
          .scaledToFit()
          .frame(width: 160)
        VStack(alignment: .leading, spacing: 24) {
          Grid(verticalSpacing: 12) {
            GridRow {
              Text("•")
              Text("Tap to show fonts with tag")
                .gridColumnAlignment(.leading)
            }
            GridRow {
              Text("•")
              Text("Long-tap to edit tags")
                .gridColumnAlignment(.leading)
            }
          }
          Grid(verticalSpacing: 12) {
            GridRow {
              Color.clear
                .gridCellUnsizedAxes([.vertical, .horizontal])
              Text("Default Tags")
                .foregroundStyle(.orange)
            }
            GridRow {
              Text("All")
                .gridColumnAlignment(.trailing)
                .foregroundStyle(.gray)
              Text("all fonts")
                .gridColumnAlignment(.leading)
            }
            GridRow {
              Text("Built-in")
                .foregroundStyle(.gray)
              Text("embedded in app")
            }
            GridRow {
              Text("Added")
                .foregroundStyle(.gray)
              Text("added by you")
            }
            GridRow {
              Text("External")
                .foregroundStyle(.gray)
              Text("residing on iCloud or external disk")
            }
          }
        }
      }
      Text(
"""
Tap the \(Image(systemName: .tagsListButtonImageName)) toolbar button to see the tag panel.
"""
      )
      Grid(horizontalSpacing: 12, verticalSpacing: 12) {
        Text("Swipe Actions")
          .foregroundStyle(.orange)
        GridRow {
          Image(systemName: "pencil")
          Text("Edit tags")
            .gridColumnAlignment(.leading)
          Image(systemName: "trash")
            .foregroundStyle(.red)
          Text("Remove user tag")
        }
      }
    }
  }

  private var toolBar1: some View {
    page(
      title: "Toolbar",
      gist:
"""
Shows the active preset name, MIDI activity indicator, active voice count, and various controls.
"""
    ) {
      Image("ToolBar1")
        .resizable()
        .scaledToFit()
      Grid(verticalSpacing: 12) {
        GridRow {
          Image(systemName: "plus.circle")
          Text("Add a new soundfont file")
            .gridColumnAlignment(.leading)
        }
        GridRow {
          Image(systemName: "tag")
          Text("Toggle tag list visibility")
        }
        GridRow {
          Image(systemName: "waveform")
          Text("Toggle effects panel visibility")
        }
        GridRow {
          Image(systemName: "chevron.left")
          Text("Show more controls (in narrow views)")
        }
      }
      Text("Long-touch on preset name to cancel all active notes (aka Panic).")
    }
  }

  private var toolBar2: some View {
    page(
      title: "More Controls",
      gist:
"""
Change the visible key range with the ❰ and ❱ buttons. \
Tap \(Image(systemName: "arrowtriangle.left.and.line.vertical.and.arrowtriangle.right")) \
to toggle keyboard sliding during playing.
"""
    ) {
      Image("ToolBar2")
      Grid(verticalSpacing: 12) {
        GridRow {
          Image(systemName: "gear")
          Text("Show application settings panel")
            .gridColumnAlignment(.leading)
        }
        GridRow {
          Image(systemName: "list.bullet")
          Text("Change visibility of presets")
        }
        GridRow {
          Image(systemName: "questionmark.circle")
          Text("Show quick-help guide")
        }
        GridRow {
          Image(systemName: "chevron.left")
            .foregroundStyle(.orange)
          Text("Hide these buttons (in narrow views)")
        }
      }
      bottomSpacer
    }
    // .navigationTitle("More Controls")
    .foregroundStyle(.teal)
  }

  private var reverb: some View {
    page(
      title: "Reverb Controls",
      gist:
"""
You can add a reverberation effect to a preset. \
Tap the \(Image(systemName: .effectsButtonImageName)) toolbar button to show. \
Swipe up/down to change room or adjust knob value.
"""
    ) {
      Image("Reverb")
        .resizable()
        .scaledToFit()
        .frame(width: 340)
      Text("Controls")
        .foregroundStyle(.orange)
      Grid(verticalSpacing: 12) {
        GridRow {
          HStack {
            Image(systemName: "arrowtriangle.down")
            Text("On")
          }
          .gridColumnAlignment(.trailing)
          .foregroundStyle(.gray)
          Text("Toggle reverb effect")
            .gridColumnAlignment(.leading)
        }
        GridRow {
          HStack {
            Image(systemName: "arrowtriangle.down")
            Text("\(Image(systemName: "lock"))")
          }
          .foregroundStyle(.gray)
          Text("Keep settings when preset changes")
        }
        GridRow {
          Text("Room")
            .foregroundStyle(.gray)
          Text("Reverberation settings for different room types")
        }
        GridRow {
          Text("Amount")
            .foregroundStyle(.gray)
          Text("Level of the source audio vs. reverberated")
        }
      }
    }
  }

  private var delay: some View {
    page(
      title: "Delay Controls",
      gist:
"""
You can also add a delay effect to a preset's audio output. Swipe up/down on knob or \
tap on label to enter numeric value.
"""
    ) {
      Image("Delay")
        .resizable()
        .scaledToFit()
        .frame(width: 340)
      Text("Controls")
        .foregroundStyle(.orange)
      Grid(verticalSpacing: 12) {
        GridRow {
          HStack {
            Image(systemName: "arrowtriangle.down")
            Text("On")
          }
          .gridColumnAlignment(.trailing)
          .foregroundStyle(.gray)
          Text("Toggle reverb effect")
            .gridColumnAlignment(.leading)
        }
        GridRow {
          HStack {
            Image(systemName: "arrowtriangle.down")
            Text("\(Image(systemName: "lock"))")
          }
          .foregroundStyle(.gray)
          Text("Keep settings when preset changes")
        }
        GridRow {
          Text("Time")
            .foregroundStyle(.gray)
          Text("Delay before replaying source audio")
        }
        GridRow {
          Text("Feedback")
            .foregroundStyle(.gray)
          Text("Level and phase of repeated audio")
        }
        GridRow {
          Text("Cutoff")
            .foregroundStyle(.gray)
          Text("Low-pass filter applied to delayed audio")
        }
        GridRow {
          Text("Amount")
            .foregroundStyle(.gray)
          Text("Level of the source audio vs. delayed")
        }
      }
    }
  }

  private var settings: some View {
    page(
      title: "Finally…",
      gist: "Here are some additional features available to you:"
    ) {
      Grid(alignment: .leadingFirstTextBaseline, verticalSpacing: 12) {
        GridRow {
          Text("•")
            .foregroundStyle(.orange)
          Text("Use as AUv3 components in supported audio apps like GarageBand and Cubasis")
            .gridColumnAlignment(.leading)
        }
        GridRow {
          Text("•")
            .foregroundStyle(.orange)
          Text("Use MIDI controllers to play notes and adjust settings")
            .gridColumnAlignment(.leading)
        }
        GridRow {
          Text("•")
            .foregroundStyle(.orange)
          Text("Connect using Bluetooth MIDI")
            .gridColumnAlignment(.leading)
        }
        GridRow {
          Text("•")
            .foregroundStyle(.orange)
          Text("Adjust the width of the virtual keyboard keys")
            .gridColumnAlignment(.leading)
        }
        GridRow {
          Text("•")
            .foregroundStyle(.orange)
          Text("Show solfège labels")
            .gridColumnAlignment(.leading)
        }
        GridRow {
          Text("•")
            .foregroundStyle(.orange)
          Text(
"""
Transpose pitch or set A4 frequency to values other than 440 Hz, either for a specific preset \
or globally.
"""
          )
            .gridColumnAlignment(.leading)
        }
      }
      .font(.body)
      Grid {
        GridRow {
          Image(systemName: "gear")
            .imageScale(.large)
          Text("Tap to access these settings and more")
            .font(.body)
        }
      }
    }
    .foregroundStyle(.teal)
  }

  private var last: some View {
    VStack(spacing: 18) {
      Text("Enjoy!")
        .font(.largeTitle)
        .foregroundStyle(.orange)
      Button {
        store.send(.dismissButtonTapped)
      } label: {
        Text("Begin making music")
          .foregroundStyle(.teal)
      }
    }
  }
}

#Preview {
  @Previewable @State var showTutorial: Bool = true
  VStack {
    Text("This is a test")
    Button {
      showTutorial = true
    } label: {
      Text("Show tutorial")
    }
  }
  .sheet(isPresented: $showTutorial) {
    NavigationStack {
      TutorialFeatureView(store: Store(initialState: .init(page: .delay)) { TutorialFeature() })
    }
  }
}
