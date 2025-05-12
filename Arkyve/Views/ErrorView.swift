//
//  ErrorView.swift
//  Arkyve
//
//  Created by Chris Jones on 05/06/2024.
//

import SwiftUI

@Observable
@MainActor
class ShowErrors {
    var show: Bool = false
    var error: ArkyveError? = nil

    func err(_ error: ArkyveError) {
        self.error = error
        AKError(String(localized: "Displayed error: \(error.localizedDescription)"))
    }

    func clear() {
        self.error = nil
        AKTrace("Clearing log")
    }
}

struct ErrorView: View {
    @Environment(MainWindowViewModel.self) var viewModel

    var body: some View {
        HStack {
            Spacer()
            Text(viewModel.showErrors.error?.localizedDescription ?? "")
            Spacer()
            Image(systemName: "multiply")
                .padding([.trailing], 5)
                .onTapGesture {
                    withAnimation {
                        viewModel.showErrors.clear()
                    }
                }
        }
        .padding([.top, .bottom], 2)
        .background(Color(#colorLiteral(red: 0.7470226884, green: 0, blue: 0, alpha: 0.5411817071)))
        .hide(if: !viewModel.showErrors.show)
    }
}

#Preview {
    let viewModel = MainWindowViewModel()

    VStack(spacing: 0) {
        ErrorView()
            .environment(viewModel)
        Rectangle()
            .background(.gray)
    }
    .task {
        viewModel.showErrors.err(ArkyveError(.extract, msg: "Hello World"))
        withAnimation {
            viewModel.showErrors.show = true
        }
    }
}
