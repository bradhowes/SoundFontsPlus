// Copyright © 2025 Brad Howes. All rights reserved.

import Foundation
import SwiftUI

#if os(iOS) || os(visionOS)

public typealias AUv3HostingController = UIHostingController

#elseif os(macOS)

public typealias AUv3HostingController = NSHostingController

extension NSView {
  func bringSubviewToFront(_ view: NSView) {}
}

#endif
