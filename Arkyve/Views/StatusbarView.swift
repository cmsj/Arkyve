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
        ZStack {
            HStack {
                Spacer()
                Text(viewModel.statusBarText)
                    .popoverTip(viewModel.tips.readOnlyStatus)
                    .tipImageStyle(.red)
#if DEBUG
                Text(viewModel.archive?.URL.absoluteString ?? "")
#endif
                Spacer()
            }
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
