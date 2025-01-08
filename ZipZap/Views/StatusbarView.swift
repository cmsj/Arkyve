//
//  StatusbarView.swift
//  ZipZap
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
                Text("\(viewModel.archive?.entries.count ?? 0) items")
                Spacer()
            }
            HStack {
                Spacer()
                ZStack {
                    ProgressView()
                        .progressViewStyle(.circular)
                        .controlSize(.small)
                        .padding([.trailing])
                        .opacity(viewModel.progress == 1.0 ? 1.0 : 0.0) // Only show if progress == 1.0 (meaning indeterminate progress)
                    ProgressView(value: viewModel.progress)
                        .progressViewStyle(.circular)
                        .controlSize(.small)
                        .padding([.trailing])
                        .opacity(viewModel.progress > 0.0 && viewModel.progress < 1.0 ? 1.0 : 0.0) // Only show if progress is between 0.0 and 1.0 (meaning determinate progress)
                }
            }
            .padding([.top, .bottom], 5)
        }
    }
}

#Preview {
    let viewModel = MainWindowViewModel()

    return VStack(spacing: 0) {
        Rectangle()
            .background(.white)
        StatusbarView()
            .environment(viewModel)
    }
}
