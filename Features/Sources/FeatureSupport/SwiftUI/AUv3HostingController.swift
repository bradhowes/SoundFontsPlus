// Copyright © 2025 Brad Howes. All rights reserved.

import Foundation
public import SwiftUI

#if os(iOS) || os(visionOS)

import UIKit
public typealias AUv3HostingController = UIHostingController

#elseif os(macOS)

import AppKit
public typealias AUv3HostingController = NSHostingController

extension NSView {
  func bringSubviewToFront(_ view: NSView) {}
}

#endif
