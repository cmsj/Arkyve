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
                Text(viewModel.archive?.error ?? "")
                Spacer()
            }
            HStack {
                Spacer()
                Text("\(viewModel.archive?.entries.count ?? 0) items")
                    .opacity(viewModel.archive?.error != nil ? 0 : 1)
                    .padding([.trailing])
            }
            .padding([.top, .bottom])
        }
    }
}

#Preview {
    StatusbarView()
        .environment(MainWindowViewModel())
}
