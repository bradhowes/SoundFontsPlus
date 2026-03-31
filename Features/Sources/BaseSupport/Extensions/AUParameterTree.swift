// Copyright © 2025 Brad Howes. All rights reserved.

import AudioUnit.AUParameters
import CasePathsCore
import Dependencies

extension AUParameterTree {

  /**
   Access parameter in tree via ParameterAddressProvider (eg enum).

   - parameter address: the address to fetch
   - returns: the found value
   */
  public subscript(address: ParameterAddress) -> AUParameter {
    guard let param = parameter(withAddress: address.rawValue) else {
      fatalError("unknown parameter address: \(address)")
    }
    return param
  }
}

// extension AUParameterTree: @retroactive @unchecked Sendable {}
