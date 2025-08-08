// Copyright © 2025 Brad Howes. All rights reserved.

import AudioUnit.AUParameters

extension AUParameterTree {

  /**
   Access parameter in tree via ParameterAddressProvider (eg enum).

   - parameter address: the address to fetch
   - returns: the found value
   */
  subscript(address: ParameterAddress) -> AUParameter {
    guard let param = parameter(withAddress: address.rawValue) else {
      fatalError("unknown parameter address: \(address)")
    }
    return param
  }
}

extension AUParameterTree {

  /// Provide pseudo-@dynamicMemberLookup functionality to AUParameterTree
  public var dynamicMemberLookup: AUParameterNodeDML { .group(self) }
}

@dynamicMemberLookup
public enum AUParameterNodeDML {
  case group(AUParameterGroup)
  case param(AUParameter)

  public var group: AUParameterGroup? {
    guard case .group(let group) = self else { return nil }
    return group
  }

  public var parameter: AUParameter? {
    guard case .param(let param) = self else { return nil }
    return param
  }

  public subscript(dynamicMember identifier: String) -> AUParameterNodeDML? {
    guard case .group(let group) = self else { return nil }
    for each in group.children where each.identifier == identifier {
      switch each {
      case let group as AUParameterGroup: return .group(group)
      case let param as AUParameter: return .param(param)
      default: break // can not happen
      }
    }
    return nil
  }
}
