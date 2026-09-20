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

struct PageViewImage: View {
  private let name: String
  private let width: CGFloat?
  private let height: CGFloat?

  init(name: String, width: CGFloat? = nil, height: CGFloat? = nil) {
    self.name = name
    self.width = width
    self.height = height
  }

  var body: some View {
    if let width {
      Image(name, bundle: Bundle.module)
        .resizable()
        .scaledToFit()
        .frame(width: width)
        .shadow(
          color: .black,
          radius: CGFloat(6.0),
          x: CGFloat(0), y: CGFloat(0))
    } else if let height {
      Image(name, bundle: Bundle.module)
        .resizable()
        .scaledToFit()
        .frame(height: height)
        .shadow(
          color: .black,
          radius: CGFloat(6.0),
          x: CGFloat(0), y: CGFloat(0))
    } else {
      Image(name, bundle: Bundle.module)
        .resizable()
        .scaledToFit()
        .shadow(
          color: .black,
          radius: CGFloat(6.0),
          x: CGFloat(0), y: CGFloat(0))
    }
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
