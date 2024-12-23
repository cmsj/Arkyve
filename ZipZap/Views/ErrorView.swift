//
//  ErrorView.swift
//  ZipZap
//
//  Created by Chris Jones on 05/06/2024.
//

import SwiftUI

@Observable
@MainActor
class ShowErrors {
    var state: Bool = false
    var msg: String? = nil
}

struct ErrorView: View {
    @Environment(MainWindowViewModel.self) var viewModel

    var body: some View {
        HStack {
            Spacer()
            Text(viewModel.showErrors.msg ?? "")
            Spacer()
            Image(systemName: "multiply")
                .padding([.trailing], 5)
                .onTapGesture {
                    withAnimation {
                        viewModel.showErrors.msg = nil
                    }
                }
        }
        .padding([.top, .bottom], 2)
        .background(Color(#colorLiteral(red: 0.7470226884, green: 0, blue: 0, alpha: 0.5411817071)))
        .hide(if: !viewModel.showErrors.state)
    }
}

//#Preview {
//    let viewModel = MainWindowViewModel()
//    viewModel.newButton()
//    viewModel.archive?.error = "Preview error"
//    let showErrors = ShowErrors()
//    showErrors.state = true
//
//    return VStack(spacing: 0) {
//        ErrorView()
//            .environment(viewModel)
//            .environment(showErrors)
//        Rectangle()
//            .background(.white)
//    }
//}
