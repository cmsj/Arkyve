//
//  HideViewModifier.swift
//  ZipZap
//
//  Created by Chris Jones on 05/06/2024.
//

import SwiftUI

// modifier
struct HideViewModifier: ViewModifier {
    let isHidden: Bool
    @ViewBuilder func body(content: Content) -> some View {
        if isHidden {
            EmptyView()
        } else {
            content
        }
    }
}

// Extending on View to apply to all Views
extension View {
    func hide(if isHidden: Bool) -> some View {
        ModifiedContent(content: self,
                        modifier: HideViewModifier(isHidden: isHidden))
    }
}
