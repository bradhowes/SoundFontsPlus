// Copyright © 2025 Brad Howes. All rights reserved.

import FeatureSupport
import SwiftUI

struct PageView<Content: View>: View {
  private let title: LocalizedStringKey
  private let gist: LocalizedStringKey
  private let rest: () -> Content
  private let bottomSpacerMinLength: CGFloat = 24.0

  @Environment(\.colorScheme) private var colorScheme

  init(title: LocalizedStringKey, gist: LocalizedStringKey, @ViewBuilder rest: @escaping () -> Content) {
    self.title = title
    self.gist = gist
    self.rest = rest
  }

  var body: some View {
    VStack(spacing: 18) {
      Text(title)
        .font(.tutorialTitle)
        .foregroundStyle(Color.tutorialTitle(colorScheme))
      Text(gist)
        .font(.tutorialGist)
      rest()
      Spacer(minLength: bottomSpacerMinLength)
    }
    .font(.tutorialBody)
    .foregroundStyle(Color.tutorialText(colorScheme))
  }
}

#if DEBUG

struct Preview: View {
  @State var showTutorial: Bool = false
  let page: Tutorial.Page

  init(page: Tutorial.Page) {
    self.page = page
  }

  var body: some View {
    VStack {
      Text("This is a test")
      Button {
        showTutorial = true
      } label: {
        Text("Show tutorial")
      }
    }
    .task {
      try? await Task.sleep(for: .milliseconds(100))
      showTutorial = true
    }
    .sheet(isPresented: $showTutorial) {
      NavigationStack {
        TutorialView(store: Store(initialState: .init(page: page)) { Tutorial() })
      }
    }
  }
}

#endif // DEBUG
