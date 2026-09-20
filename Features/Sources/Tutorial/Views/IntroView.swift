// Copyright © 2025 Brad Howes. All rights reserved.

import FeatureSupport
import SwiftUI

struct IntroView: View {

  var body: some View {
    PageView(
      title: "Welcome to SoundFonts+",
      gist:
"""
This brief tutorial will introduce you to the various parts of the app.

The tutorial will not appear upon future launches of the app, but you can always view it again via the \
\(Image(systemName: .settingsButtonImageName)) Settings panel.
"""
    ) {
      Text("Swipe left or tap along the right edge of this view to continue.")
        .italic(true)
    }
  }
}

#if DEBUG

#Preview {
  Preview(page: .intro)
}

#endif // DEBUG
