import FeatureSupport
import SwiftUI

struct TagsView: View {
  @Environment(\.horizontalSizeClass) private var horizontalSizeClass

  var body: some View {
    PageView(
      title: "Tags",
      gist:
"""
Tags help organize your font collection as it grows, filtering which fonts are visible. The \
\(Image(systemName: .tagsListButtonImageName)) button controls their visibility.
"""
    ) {
      HStack(alignment: .top) {
        Image("TagsList", bundle: Bundle.module)
          .resizable()
          .scaledToFit()
          .frame(width: 160)
          .shadow(
            color: .black,
            radius: CGFloat(6.0),
            x: CGFloat(0), y: CGFloat(0))
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
            Text("Default Tags")
              .foregroundStyle(Color.alternateAccentColor)
            GridRow {
              Text("All")
                .gridColumnAlignment(.trailing)
                .foregroundStyle(.gray)
              Text("Everything")
                .gridColumnAlignment(.leading)
            }
            GridRow {
              Text("Built-in")
                .foregroundStyle(.gray)
              Text("Embedded in app")
            }
            GridRow {
              Text("Added")
                .foregroundStyle(.gray)
              Text("Added by you")
            }
            GridRow {
              Text("External")
                .foregroundStyle(.gray)
              Text("On iCloud or external disk")
            }
          }
          if horizontalSizeClass != .compact {
            Text("Swipe Actions")
              .foregroundStyle(Color.alternateAccentColor)
            Grid {
              GridRow {
                Image(systemName: .editButtonImageName)
                Text("Edit tags")
                  .gridColumnAlignment(.leading)
              }
              GridRow {
                Image(systemName: .deleteButtonImageName)
                  .foregroundStyle(.red)
                Text("Remove user tag")
              }
            }
          }
        }
      }
      if horizontalSizeClass == .compact {
        Text("Swipe Actions")
          .foregroundStyle(Color.alternateAccentColor)
        HStack(spacing: 18) {
          Grid {
            GridRow {
              Image(systemName: .editButtonImageName)
              Text("Edit tags")
                .gridColumnAlignment(.leading)
            }
          }
          Grid {
            GridRow {
              Image(systemName: .deleteButtonImageName)
                .foregroundStyle(.red)
              Text("Remove user tag")
            }
          }
        }
      }
    }
  }
}

#if DEBUG

#Preview {
  Preview(page: .tags)
}

#endif // DEBUG
