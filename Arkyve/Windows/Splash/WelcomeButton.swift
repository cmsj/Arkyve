//
//  WelcomeButton.swift
//  Arkyve
//
//  Created by Chris Jones on 15/07/2025.
//
import SwiftUI

struct WelcomeButton: View {
    @State private var isHover: Bool = false
    var iconName: String
    var text: String

    var body: some View {
        HStack(spacing: 0) {
            Image(systemName: iconName)
                .font(.system(size: 16, weight: .medium))
                .foregroundStyle(.secondary)
                .padding(10)
                .frame(width: 38)
            Text(text)
                .font(.system(size: 14, weight: .medium))
                .padding([.leading], 0)
            Spacer()
        }
        .background(
            RoundedRectangle(cornerRadius: 7, style: .continuous)
                .fill(.gray.opacity(isHover ? 0.15 : 0.1))
        )
        .frame(width: 349, height: 35)
        .padding([.bottom], 7)
        .onHover(perform: { isHover in
            withAnimation(.linear(duration: 0.2)) {
                self.isHover = isHover
            }
        })
    }
}
