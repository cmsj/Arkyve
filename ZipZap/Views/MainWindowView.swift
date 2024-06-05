//
//  MainWindowView.swift
//  ZipZap
//
//  Created by Chris Jones on 10/05/2024.
//

import SwiftUI

struct MainWindowView: View {
    var viewModel = MainWindowViewModel()
    @State var windowTitle = "ZipZap"
    @State var showFileChooser = false
    @State var showLog: Bool = false
    @State var showError: Bool = false

    var body: some View {
        VStack(spacing: 0) {
            HStack {
                Spacer()
                Text(viewModel.archive?.error ?? "")
                Spacer()
            }
            .padding([.top, .bottom], 2)
            .background(Color(#colorLiteral(red: 0.7470226884, green: 0, blue: 0, alpha: 0.5411817071)))
            .hide(if: !showError)

            TableView()
                .environment(viewModel)
            StatusbarView()
                .environment(viewModel)
        }
        .toolbar(id: "Main") {
            ToolbarContentView(viewModel: viewModel)
        }
        .navigationTitle(windowTitle)
        .frame(maxWidth: .infinity, maxHeight: .infinity)
        .onChange(of: viewModel.archive?.error) { old, new in
            // Nicely animate the error view appearing/disappearing
            if showError && new == nil {
                withAnimation {
                    showError = false
                }
            } else if !showError && new != nil {
                withAnimation {
                    showError = true
                }
            }
        }
    }
}

#Preview {
    let view = MainWindowView()
    view.viewModel.newButton()
    view.viewModel.archive?.error = "Testing error"
    return view
}
