//
//  SoundFontsPlusAUMainView.swift
//  SoundFontsPlusAU
//
//  Created by Brad Howes on 6/29/25.
//

import SwiftUI

struct SoundFontsPlusAUMainView: View {
    var parameterTree: ObservableAUParameterGroup
    
    var body: some View {
        ParameterSlider(param: parameterTree.global.gain)
    }
}
