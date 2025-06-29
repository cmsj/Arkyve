//
//  CloseButton.swift
//  Arkyve
//
//  Created by Chris Jones on 29/06/2025.
//

import SwiftUI

public struct CloseButton: View {
    @Environment(\.dismissWindow) var dismissWindow
    @State private var isHover: Bool = false

    public var body: some View {
        Image(systemName: "xmark.circle.fill")
            .foregroundStyle(isHover ? .secondary : .tertiary)
            .onHover(perform: { isHover in
                withAnimation(.linear(duration: 0.2)) {
                    self.isHover = isHover
                }
            })
            .onTapGesture { dismissWindow() }
    }
}
