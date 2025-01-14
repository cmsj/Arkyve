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

    @FocusState private var renameEntry: UUID?

    var tableViewTip = TableViewTip()

    var body: some View {
        // FIXME: This @Bindable is an ugly hack: https://www.hackingwithswift.com/books/ios-swiftui/sharing-observable-objects-through-swiftuis-environment
        @Bindable var viewModel = viewModel

        VStack(spacing: 0) {
            ErrorView()
                .environment(viewModel)
            TableView(renameEntryFocus: $renameEntry)
                .environment(viewModel)
                .popoverTip(tableViewTip, arrowEdge: .leading)
                .disabled(viewModel.archive == nil)
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
        .alert("Save before closing?", isPresented: $viewModel.showSavePrompt) {
            Button("Save") {
                viewModel.saveButton()
            }
            Button("Close", role: .destructive) {
                viewModel.closeButton(force: true)
            }
            Button("Cancel", role: .cancel) {}
        } message: {
            Text("Archive has unsaved changes, do you want to save it?")
        }
//        .onChange(of: viewModel.archive, initial: true, { oldValue, newValue in
//            showFilePicker = (newValue == nil ? true : false)
//        })
        .task {
            do {
                try Tips.configure()
            }
            catch {
                print("Error initializing TipKit \(error.localizedDescription)")
            }
        }
//        .fileImporter(isPresented: $showFilePicker, allowedContentTypes: [.archive], allowsMultipleSelection: false, onCompletion: { result in
//            switch result {
//            case .success(let files):
//                files.forEach { file in
//                    let gotAccess = file.startAccessingSecurityScopedResource()
//                    if !gotAccess { return }
//
//                    viewModel.openArchive(url: file)
//                    file.stopAccessingSecurityScopedResource()
//                }
//            case .failure(let error):
//                viewModel.showErrors.err(ArchiveError.ArchiveOpenError(archive: "", error: error.localizedDescription))
//            }
//        })
    }
}

#Preview {
    MainWindowView()
}
