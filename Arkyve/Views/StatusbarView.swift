//
//  StatusbarView.swift
//  Arkyve
//
//  Created by Chris Jones on 04/06/2024.
//

import SwiftUI

struct StatusbarView: View {
    @Environment(MainWindowViewModel.self) var viewModel

    var body: some View {
        VStack {
            HStack {
                Spacer()
                Text(viewModel.statusBarText)
                    .padding(.vertical, 5)
                    .popoverTip(viewModel.tips.readOnlyStatus)
                    .tipImageStyle(.red)
                Spacer()
            }
#if DEBUG
            Text(viewModel.archive?.URL.absoluteString ?? "")
                .padding([.bottom], 5)
                .hide(if: viewModel.archive == nil)
#endif
        }
    }
}

#Preview {
    let viewModel = MainWindowViewModel()

    VStack(spacing: 0) {
        Rectangle()
            .background(.white)
        StatusbarView()
            .environment(viewModel)
    }
}
