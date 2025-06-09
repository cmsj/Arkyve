//
//  ErrorView.swift
//  Arkyve
//
//  Created by Chris Jones on 05/06/2024.
//

import SwiftUI

struct ErrorView: View {
    @Environment(ArchiveViewModel.self) var viewModel

    var body: some View {
        HStack {
            Spacer()
            Text(viewModel.errors.error?.localizedDescription ?? "")
            Spacer()
            Image(systemName: "multiply")
                .padding([.trailing], 5)
                .onTapGesture {
                    withAnimation {
                        viewModel.errors.clear()
                    }
                }
        }
        .padding([.top, .bottom], 2)
        .background(Color(#colorLiteral(red: 0.7470226884, green: 0, blue: 0, alpha: 0.5411817071)))
        .hide(if: !viewModel.errors.show)
    }
}

//#Preview {
//    let viewModel = ArchiveViewModel()
//
//    VStack(spacing: 0) {
//        ErrorView()
//            .environment(viewModel)
//        Rectangle()
//            .background(.gray)
//    }
//    .task {
//        viewModel.errors.err(ArkyveError(.extract, msg: "Hello World"))
//        withAnimation {
//            viewModel.errors.show = true
//        }
//    }
//}
