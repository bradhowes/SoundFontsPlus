// Copyright © 2025 Brad Howes. All rights reserved.

import HostAUv3s
import SwiftUI

#if canImport(UIKit)

import UIKit


public struct AUv3View: UIViewControllerRepresentable {
  private let instance: AUv3Instance

  public init(instance: AUv3Instance) {
    self.instance = instance
  }

  public func makeUIViewController(context: Context) -> ViewController {
    instance.viewController
  }

  public func updateUIViewController(_ uiViewController: ViewController, context: Context) {

  }
}

#else

import AppKit

public struct AUv3View: NSViewControllerRepresentable {
  private let instance: AUv3Instance

  public init(instance: AUv3Instance) {
    self.instance = instance
  }

  public func makeNSViewController(context: Context) -> NSViewController {
    instance.viewController
  }

  public func updateNSViewController(_ uiViewController: ViewController, context: Context) {

  }
}

#endif
