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
    @State var showFilePicker: Bool = false

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
            withAnimation {
                if viewModel.showErrors.state && new == nil {
                    viewModel.showErrors.state = false
                } else if !viewModel.showErrors.state && new != nil {
                    viewModel.showErrors.state = true
                }
            }
        }
        .toolbar(id: "Main") {
            ToolbarContentView(viewModel: viewModel, renameEntry: $renameEntry)
        }
        .navigationTitle("\(windowTitle)\(viewModel.archive?.dirty ?? false ? " (Unsaved)" : "")")
        .frame(maxWidth: .infinity, maxHeight: .infinity)
        .onChange(of: viewModel.archive, initial: true, { oldValue, newValue in
            showFilePicker = (newValue == nil ? true : false)
        })
        .task {
            do {
                try Tips.configure()
            }
            catch {
                print("Error initializing TipKit \(error.localizedDescription)")
            }
        }
        .fileImporter(isPresented: $showFilePicker, allowedContentTypes: [.archive], allowsMultipleSelection: false, onCompletion: { result in
            switch result {
            case .success(let files):
                files.forEach { file in
                    let gotAccess = file.startAccessingSecurityScopedResource()
                    if !gotAccess { return }

                    viewModel.openArchive(url: file)
                    file.stopAccessingSecurityScopedResource()
                }
            case .failure(let error):
                viewModel.showErrors.err(ArchiveError.ArchiveOpenError(archive: "", error: error.localizedDescription))
            }
        })
    }
}

#Preview {
    MainWindowView()
}
