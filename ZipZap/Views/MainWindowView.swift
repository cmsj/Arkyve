//
//  MainWindowView.swift
//  ZipZap
//
//  Created by Chris Jones on 10/05/2024.
//

import SwiftUI

struct MainWindowView: View {
    var viewModel: MainWindowViewModel = MainWindowViewModel()
    @State var windowTitle = "ZipZap"
    @State var showFileChooser = false
    @State var showLog: Bool = false
    @State var showErrors = ShowErrors()

    @FocusState private var renameEntry: UUID?

    var body: some View {
        VStack(spacing: 0) {
            ErrorView()
                .environment(viewModel)
                .environment(showErrors)
            TableView(renameEntry: $renameEntry)
                .environment(viewModel)
            StatusbarView()
                .environment(viewModel)
        }
        .focusedSceneValue(\.activeViewModel, viewModel)
        .focusable()
        .focusEffectDisabled()
        .onChange(of: viewModel.archive?.error, initial: true) { old, new in
            // Nicely animate the error view appearing/disappearing
            if showErrors.state && new == nil {
                withAnimation {
                    showErrors.state = false
                }
            } else if !showErrors.state && new != nil {
                withAnimation {
                    showErrors.state = true
                }
            }
        }
        .toolbar(id: "Main") {
            ToolbarContentView(viewModel: viewModel, renameEntry: $renameEntry)
        }
        .navigationTitle(windowTitle)
        .frame(maxWidth: .infinity, maxHeight: .infinity)
    }
}

#Preview {
    MainWindowView()
}
