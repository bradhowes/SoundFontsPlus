import ComposableArchitecture
import Sharing
import SwiftUI

@Reducer
public struct TutorialFeature {

  public enum Page: Int, CaseIterable {
    case intro = 1
    case fonts
    case tags
    case presets
    case favorites
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

    public init(page: Page = .intro) {
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

  public init(store: StoreOf<TutorialFeature>) {
    self.store = store
  }

  public var body: some View {
    ZStack(alignment: .top) {
      TabView(selection: $store.page) {
        ForEach(TutorialFeature.Page.allCases, id: \.self) { page in
          switch page {
          case .intro: intro
          case .fonts: fonts
          case .tags: tags
          case .presets: presets
          case .favorites: favorites
          case .toolBar1: toolBar1
          case .toolBar2: toolBar2
          case .reverb: reverb
          case .delay: delay
          case .settings: settings
          case .last: last
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
          .frame(width: 80)
          .frame(maxHeight: .infinity)
          .contentShape(Rectangle())
          .onTapGesture {
            store.send(.prev)
          }
        Spacer()
        Rectangle()
          .fill(.clear)
          .frame(width: 80)
          .frame(maxHeight: .infinity)
          .contentShape(Rectangle())
          .onTapGesture {
            store.send(.next)
          }
      }
    }
    .navigationTitle("")
    .toolbar {
      ToolbarItem(placement: .automatic) {
        Button("Done") { store.send(.dismissButtonTapped, animation: .default) }
      }
    }
  }
}

extension Tab {

  public init(page: TutorialFeature.Page, @ViewBuilder content: () -> Content)
  where Value == TutorialFeature.Page, Label == EmptyView, Content: View {
    self.init(value: page, content: content)
  }
}

extension TutorialFeatureView {

  private var intro: some View {
    VStack(spacing: 18) {
      Text("Welcome to SoundFonts+")
        .font(.largeTitle)
        .foregroundStyle(.orange)
      VStack(alignment: .leading, spacing: 18) {
        Text("This brief tutorial will introduce you to the various parts of the app.")
          .foregroundStyle(.teal)
          .font(.title3)
        Text("The tutorial will not appear upon future launches of the app, but you can always view it again via the \(Image(systemName: "gear")) Settings panel.")
        // .font(.title3)
          .foregroundStyle(.teal)
          .font(.title3)
      }
      Text("Swipe left or tap along the right edge of the screen to continue.")
        .font(.body)
        .italic(true)
        .foregroundStyle(.teal)
      Spacer()
    }
  }

  private var fonts: some View {
    VStack(spacing: 18) {
      Text("SoundFonts List")
        .font(.largeTitle)
        .foregroundStyle(.orange)
      Text("The panel on the left-hand side shows names of the installed soundfont files.")
        .font(.title3)
      HStack {
        Image("FontsList")
          .resizable()
          .scaledToFit()
          .frame(width: 120)
        VStack(spacing: 14) {
          Text("Tap to activate font and view its presets (long-tap to edit).")
            .font(.body)
          Grid {
            Text("Swipe Actions")
              .font(.subheadline)
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
      Grid {
        GridRow {
          Image(systemName: "plus.circle")
            .imageScale(.large)
          Text("Adds soundfont files from iCloud or external disk. Long-tap to select fonts to remove.")
            .font(.body)
        }

      }
      Spacer()
    }
    .foregroundStyle(.teal)
  }

  private var tags: some View {
    VStack(spacing: 18) {
      Text("Tags List")
        .font(.largeTitle)
        .foregroundStyle(.orange)
      Text("Tags help organize your font collection as it grows. " +
           "They allow you to quickly change which fonts are visible at any time.")
      .font(.title3)
      HStack {
        Image("TagsList")
          .resizable()
          .scaledToFit()
          .frame(width: 120)
        VStack(alignment: .leading, spacing: 14) {
          Text("Tap tag to only show fonts with that tag.")
          Text("Edit font to change its tags.")
          Text("Long-tap tag to access tag editor.")
          Text("Use editor to add new tags, rearrange them, change a name, or delete a tag.")
        }
        .font(.body)
      }
      Grid {
        GridRow {
          Image(systemName: "tag")
            .imageScale(.large)
          Text("Shows/hides the tag panel below the list of fonts.")
            .font(.body)
        }

      }
      Spacer()
    }
    .foregroundStyle(.teal)
  }

  private var presets: some View {
    VStack(spacing: 18) {
      Text("Presets List")
        .font(.largeTitle)
        .foregroundStyle(.orange)
      Text("The list to the right of the fonts list shows visible presets in the selected font file. " +
           "Any favorites you create will appear in gold.")
      .font(.title3)
      Image("PresetsList")
        .resizable()
        .scaledToFit()
        .padding([.leading, .trailing], 16)
      // .frame(width: 180)
      Grid {
        Text("Swipe Actions")
          .font(.subheadline)
          .foregroundStyle(.orange)
        GridRow {
          Image(systemName: "pencil")
          Text("Edit preset")
            .gridColumnAlignment(.leading)
          Image(systemName: "eye.slash")
            .foregroundStyle(.gray)
          Text("Hide preset")
            .gridColumnAlignment(.leading)
        }
        GridRow {
          Image(systemName: "star")
            .foregroundStyle(.orange)
          Text("Create favorite")
            .gridColumnAlignment(.leading)
          Image(systemName: "trash")
            .foregroundStyle(.red)
          Text("Remove favorite")
        }
      }
      Spacer()
    }
    .foregroundStyle(.teal)
  }

  private var favorites: some View {
    VStack(spacing: 18) {
      Text("Favorites")
        .font(.largeTitle)
        .foregroundStyle(.orange)
      Text("Copies of presets are known as \"favorites\". " +
           "They provide a way to customize a built-in preset with your own values.")
      .font(.title3)
      Image("PresetsList")
        .resizable()
        .scaledToFit()
        .padding([.leading, .trailing], 16)
      Text("Presets normally appear below their original preset, but you can change this in the settings " +
           "page.")
      .font(.body)
      Spacer()
    }
    .foregroundStyle(.teal)
  }

  private var toolBar1: some View {
    VStack(spacing: 18) {
      Text("Tool Bar")
        .font(.largeTitle)
        .foregroundStyle(.orange)
      Text("Shows the active preset, MIDI activity, active voice count, and various controls. " +
           "Long-touch to cancel all notes.")
      .font(.title3)
      Image("ToolBar1")
        .resizable()
        .scaledToFit()
        .padding([.leading, .trailing], 16)
      Grid {
        GridRow {
          Image(systemName: "plus.circle")
          Text("Add a new soundfont file")
            .gridColumnAlignment(.leading)
        }
        GridRow {
          Image(systemName: "tag")
          Text("Show or hide tag list")
            .gridColumnAlignment(.leading)
        }
        GridRow {
          Image(systemName: "waveform")
          Text("Toggle visibility of effects panel")
            .gridColumnAlignment(.leading)
        }
        GridRow {
          Image(systemName: "chevron.left")
          Text("Show/hide more controls on phone devices")
        }
      }
      Spacer()
    }
    .foregroundStyle(.teal)
  }

  private var toolBar2: some View {
    let img = Image(systemName: "arrowtriangle.left.and.line.vertical.and.arrowtriangle.right")
    return VStack(spacing: 18) {
      Text("More Controls")
        .font(.largeTitle)
        .foregroundStyle(.orange)
      Text("Change the visible key range with the ❰ and ❱ buttons. Tap \(img) to toggle keyboard sliding during playing.")
      .font(.title3)
      Image("ToolBar2")
        .resizable()
        .scaledToFit()
        .padding([.leading, .trailing], 16)
      // .frame(width: 180)
      Grid {
        GridRow {
          Image(systemName: "gear")
          Text("Show application settings panel")
            .gridColumnAlignment(.leading)
        }
        GridRow {
          Image(systemName: "list.bullet")
          Text("Change visibility of presets")
            .gridColumnAlignment(.leading)
        }
        GridRow {
          Image(systemName: "questionmark.circle")
          Text("Show quick-help guide")
            .gridColumnAlignment(.leading)
        }
        GridRow {
          Image(systemName: "chevron.left")
            .foregroundStyle(.orange)
          Text("Hide these buttons (on phone devices)")
            .gridColumnAlignment(.leading)
        }
      }
      Spacer()
    }
    .foregroundStyle(.teal)
  }

  private var reverb: some View {
    VStack(spacing: 18) {
      Text("Reverb Controls")
        .font(.largeTitle)
        .foregroundStyle(.orange)
      Text("Select from predefined reverb room definitions. " +
           "Swipe up/down on knob to control mix.")
      .font(.title3)
      Image("Reverb")
        .resizable()
        .scaledToFit()
        .padding([.leading, .trailing], 16)
      // .frame(width: 180)
      Grid {
        GridRow {
          HStack {
            Image(systemName: "arrowtriangle.down")
            Text("Reverb")
          }
          Text("Enable/disable reverb effect")
        }
        GridRow {
          HStack {
            Image(systemName: "arrowtriangle.down")
            Text("Lock")
          }
          .gridColumnAlignment(.leading)
          .foregroundStyle(.orange)
          Text("Keep settings when preset changes")
            .gridColumnAlignment(.leading)
        }
      }
      Spacer()
    }
    .foregroundStyle(.teal)
  }

  private var delay: some View {
    VStack(spacing: 18) {
      Text("Delay Controls")
        .font(.largeTitle)
        .foregroundStyle(.orange)
      Text("Maximum 2 seconds delay with feedback control. Cutoff setting affects low-pass filter.")
      .font(.title3)
      Image("Delay")
        .resizable()
        .scaledToFit()
        .padding([.leading, .trailing], 16)
      // .frame(width: 180)
      Grid {
        GridRow {
          HStack {
            Image(systemName: "arrowtriangle.down")
            Text("Reverb")
          }
          Text("Enable/disable delay effect")
        }
        GridRow {
          HStack {
            Image(systemName: "arrowtriangle.down")
            Text("Lock")
          }
          .gridColumnAlignment(.leading)
          .foregroundStyle(.orange)
          Text("Keep settings when preset changes")
            .gridColumnAlignment(.leading)
        }
      }
      Spacer()
    }
    .foregroundStyle(.teal)
  }

  private var settings: some View {
    VStack(spacing: 18) {
      Text("Last but not Least")
        .font(.largeTitle)
        .foregroundStyle(.orange)
      Text("Here are some of the additional features available to you:")
      .font(.title3)
      Grid {
        GridRow {
          Image(systemName: "minus")
            .imageScale(.small)
            .foregroundStyle(.orange)
          Text("Use as AUv3 components in supported audio apps")
            .gridColumnAlignment(.leading)
        }
        GridRow {
          Image(systemName: "minus")
            .imageScale(.small)
            .foregroundStyle(.orange)
          Text("Receive MIDI commands from external controllers")
            .gridColumnAlignment(.leading)
        }
        GridRow {
          Image(systemName: "minus")
            .imageScale(.small)
            .foregroundStyle(.orange)
          Text("Connect using Bluetooth MIDI")
            .gridColumnAlignment(.leading)
        }
        GridRow {
          Image(systemName: "minus")
            .imageScale(.small)
            .foregroundStyle(.orange)
          Text("Show solfège labels")
            .gridColumnAlignment(.leading)
        }
        GridRow {
          Image(systemName: "minus")
            .imageScale(.small)
            .foregroundStyle(.orange)
          Text("Adjust the width of the keyboard keys")
            .gridColumnAlignment(.leading)
        }
        GridRow {
          Image(systemName: "minus")
            .imageScale(.small)
            .foregroundStyle(.orange)
          Text("Transpose instrument or set A4 frequency to values other than 440 Hz")
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
      Spacer()
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
  NavigationStack {
    TutorialFeatureView(store: Store(initialState: .init(page: .intro)) { TutorialFeature() })
  }
}
