import HelpInfoSpotlightOverlay
import SwiftUI

/**
 Custom helpInfo overlay that honors the current color scheme and uses .mainAccentColor to tint the controls.

 - parameter helpItem: the ID of the item being spotlit
 - parameter actions: the actions for the controls to use
 - parameter colorScheme: the current color scheme
 - returns: the view that shows the help info for the current item
 */
@MainActor
public func customHelpInfoOverlay(
  for helpItem: HelpInfoProvider,
  actions: HelpInfoSpotlightOverlayActions,
  colorScheme: ColorScheme
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
