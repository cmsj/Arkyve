//
//  MainWindowView.swift
//  ZipZap
//
//  Created by Chris Jones on 10/05/2024.
//

import SwiftUI
import TipKit

struct MainWindowView: View {
    @State var viewModel: MainWindowViewModel = MainWindowViewModel()
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
                viewModel.showErrors.show = new != nil
            }
        }
        .toolbar(id: "Main") {
            ToolbarContentView(viewModel: viewModel, renameEntry: $renameEntry)
        }
        .navigationTitle(windowTitle)
        .navigationSubtitle(viewModel.navSubtitleText)
        .frame(maxWidth: .infinity, maxHeight: .infinity)
        .task {
            do {
                try Tips.configure()
            }
            catch {
                print("Error initializing TipKit \(error.localizedDescription)")
            }
        }
//        .task {
//            if let url = documentURL {
//                Task {
//                    await viewModel.openArchive(url: url)
//                }
//            }
//        }
    }
}

//#Preview {
//    MainWindowView(document: <#Binding<ArchiveDocument>#>, fullURL: <#URL?#>)
//}
