// From: https://github.com/scr037/ToggleableSecureField/blob/main/Sources/ToggleableSecureField/ToggleableSecureField.swift

import SwiftUI

public struct ToggleableSecureFieldSheet: View {
    @Environment(\.dismiss) var dismiss
    @Environment(ArchiveViewModel.self) var viewModel

    @State private var isSecure: Bool
    @State private var password: String

    private var title: String
    private var text: Binding<String>
    private var prompt: Text?

    public init(
        _ isSecure: Bool = true,
        title: String,
        text: Binding<String>,
        prompt: Text?
    ) {
        self.isSecure = isSecure
        self.title = title
        self.text = text
        self.prompt = prompt
        self.password = text.wrappedValue
    }

    func savePassword() {
        viewModel.passphraseToSave = password
        viewModel.setDirty()
        dismiss()
    }

    public var body: some View {
        Form {
            if !viewModel.format.canEncrypt {
                HStack {
                    Image(systemName: "exclamationmark.triangle")
                        .foregroundColor(.yellow)
                        .font(.title)
                    Text("Arkyve can only apply passwords when saving as a Zip archive.")
                }
                .padding([.leading, .trailing, .top])
            }
            HStack {
                Text(title)
                if isSecure {
                    SecureField(title, text: $password, prompt: prompt)
                        .autocorrectionDisabled()
                        .labelsHidden()
                        .focusEffectDisabled()
                        .onSubmit {
                            savePassword()
                        }
                } else {
                    TextField(title, text: $password, prompt: prompt)
                        .autocorrectionDisabled()
                        .labelsHidden()
                        .focusEffectDisabled()
                        .onSubmit {
                            savePassword()
                        }
                }
            }
            .padding()

            HStack {
                Spacer()
                Button("Cancel") {
                    dismiss()
                }

                Button(role: .destructive) {
                    password = ""
                    savePassword()
                } label: {
                    Text("Remove Password")
                }
                .disabled(viewModel.passphraseToSave == "")

                Button("Set Password") {
                    savePassword()
                }
                .buttonStyle(.borderedProminent)
            }
            .padding()
        }
        .textFieldStyle(
            .toggleableSecureField(isSecure: $isSecure)
        )
    }
}
