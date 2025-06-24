// From: https://github.com/scr037/ToggleableSecureField/blob/main/Sources/ToggleableSecureField/ToggleableSecureFieldStyle.swift

import SwiftUI

@MainActor
struct ToggleableSecureFieldStyle: @preconcurrency TextFieldStyle {
    @Binding var isSecure: Bool

    init(isSecure: Binding<Bool>) {
        self._isSecure = isSecure
    }

    func _body(configuration: TextField<_Label>) -> some View {
        TextField("", text: .constant(""))
            .overlay(
                configuration
                    .overlay(
                        HStack {
                            Spacer()
                            Button(
                                action: { isSecure.toggle() },
                                label: {
                                    Group {
                                        Image(systemName: isSecure ? "eye.slash" : "eye")
                                    }
                                    .tint(.accentColor)
                                }
                            )
                            .buttonStyle(.plain)
                            .padding(.trailing, 8)
                            .padding(.vertical, 4)
                        }
                    )
            )
    }
}

@MainActor
extension TextFieldStyle where Self == ToggleableSecureFieldStyle {
    static func toggleableSecureField(isSecure: Binding<Bool>) -> Self {
        return ToggleableSecureFieldStyle(isSecure: isSecure)
    }
}
