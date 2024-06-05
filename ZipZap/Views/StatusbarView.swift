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
        VStack {
            HStack {
                Spacer()
                Text("\(viewModel.archive?.entries.count ?? 0) items")
                Spacer()
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
