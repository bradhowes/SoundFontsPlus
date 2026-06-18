// Copyright © 2025 Brad Howes. All rights reserved.

import AudioUnit.AUParameters
import CasePathsCore
import Dependencies

extension AUParameterTree {

  /**
   Access parameter in tree via `ParameterAddress` enum.

   - parameter address: the address to fetch
   - returns: the current value
   */
  public subscript(address: ParameterAddress) -> AUParameter? {
    parameter(withAddress: address.rawValue)
  }
}
