// Copyright © 2025 Brad Howes. All rights reserved.

public import Sharing

extension SharedKey where Self == AppStorageKey<Bool>.Default {

  public static var showedTutorial: Self { Self[.appStorage("showedTutorial"), default: false] }
}
