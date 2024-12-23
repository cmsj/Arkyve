//
//  MainWindowView.swift
//  ZipZap
//
//  Created by Chris Jones on 10/05/2024.
//

import SwiftUI
import TipKit

struct MainWindowView: View {
    var viewModel: MainWindowViewModel = MainWindowViewModel()
    @State var windowTitle = "ZipZap"
    @State var showFileChooser = false
    @State var showLog: Bool = false

    @FocusState private var renameEntry: UUID?

    var tableViewTip = TableViewTip()

    var body: some View {
        VStack(spacing: 0) {
            ErrorView()
                .environment(viewModel)
            TableView(renameEntryFocus: $renameEntry)
                .environment(viewModel)
                .popoverTip(tableViewTip, arrowEdge: .leading)
            StatusbarView()
                .environment(viewModel)
        }
        .focusedSceneValue(\.activeViewModel, viewModel)
        .focusable()
        .focusEffectDisabled()
        .onChange(of: viewModel.showErrors.error, initial: true) { old, new in
            // Nicely animate the error view appearing/disappearing
            if viewModel.showErrors.state && new == nil {
                withAnimation {
                    viewModel.showErrors.state = false
                }
            } else if !viewModel.showErrors.state && new != nil {
                withAnimation {
                    viewModel.showErrors.state = true
                }
            }
        }
        .toolbar(id: "Main") {
            ToolbarContentView(viewModel: viewModel, renameEntry: $renameEntry)
        }
        .navigationTitle("\(windowTitle)\(viewModel.archive?.dirty ?? false ? " (Unsaved)" : "")")
        .frame(maxWidth: .infinity, maxHeight: .infinity)
        .task {
            // Configure and load your tips at app launch.
            do {
                try Tips.configure([
                    .displayFrequency(.immediate),
                    .datastoreLocation(.applicationDefault)
                ])
            }
            catch {
                // Handle TipKit errors
                print("Error initializing TipKit \(error.localizedDescription)")
            }
        }
    }
}

#Preview {
    MainWindowView()
}
