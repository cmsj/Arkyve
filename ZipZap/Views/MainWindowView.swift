//
//  MainWindowView.swift
//  ZipZap
//
//  Created by Chris Jones on 10/05/2024.
//

import SwiftUI
import TipKit

struct MainWindowView: View {
    @Environment(\.undoManager) var undoManager

    var viewModel: MainWindowViewModel
    var documentURL: URL?
    @State var windowTitle = "ZipZap"
    var document: Archive

    @FocusState private var renameEntry: UUID?

    var tableViewTip = TableViewTip()

    init(document: Archive, fullURL: URL?) {
        viewModel = MainWindowViewModel(for: document)
        self.document = document
        documentURL = fullURL
    }

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
        .task {
            do {
                try Tips.configure()
            }
            catch {
                print("Error initializing TipKit \(error.localizedDescription)")
            }
        }
        .task {
            if let url = documentURL {
                Task {
                    await viewModel.openArchive(url: url)
                }
            }
        }
        .onAppear {
            undoManager?.registerUndo(withTarget: document, handler: {
                print($0, "undo")
            })
        }
    }
}

//#Preview {
//    MainWindowView(document: <#Binding<ArchiveDocument>#>, fullURL: <#URL?#>)
//}
