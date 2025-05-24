// Copyright © 2025 Brad Howes. All rights reserved.

import Foundation

#if compiler(<6.0) || !hasFeature(InferSendableFromCaptures)
extension KeyPath: @unchecked @retroactive Sendable {}
#endif

