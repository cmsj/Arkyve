//
//  MainWindowView.swift
//  Arkyve
//
//  Created by Chris Jones on 10/05/2024.
//

import SwiftUI

struct MainWindowView: View {
    @State var viewModel: MainWindowViewModel = MainWindowViewModel()
    @State var windowTitle = "Arkyve"
    @FocusState private var renameEntry: UUID?

    @Environment(\.dismissWindow) private var dismissWindow

    var body: some View {
        // NOTE: This @Bindable is an ugly hack: https://www.hackingwithswift.com/books/ios-swiftui/sharing-observable-objects-through-swiftuis-environment
        @Bindable var viewModel = viewModel

        VStack(spacing: 0) {
            ErrorView()
                .environment(viewModel)
            TableView(renameEntryFocus: $renameEntry)
                .environment(viewModel)
                .disabled(viewModel.archive == nil || viewModel.disableUI == true)
                .hide(if: viewModel.archive == nil)
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
//        .onChange(of: viewModel.shouldCloseWindow, { oldValue, newValue in
//            if newValue == true {
//                viewModel.closeButton()
//                dismissWindow()
//                viewModel.shouldCloseWindow = false
//            }
//        })
        .toolbar(id: "Main") {
            ToolbarContentView(viewModel: viewModel, renameEntry: $renameEntry)
        }
        .navigationTitle(windowTitle)
        .navigationSubtitle(viewModel.navSubtitleText)
        .frame(maxWidth: .infinity, maxHeight: .infinity)
        .alert("Close without saving?", isPresented: $viewModel.showSavePrompt) {
            Button(role: .cancel) {
                viewModel.postSavePromptClosure = nil
            } label: {
                Text("Cancel")
            }
            Button(role: .destructive) {
                viewModel.closeArchive()

                viewModel.postSavePromptClosure?()
                viewModel.postSavePromptClosure = nil
            } label: {
                Text("Close Archive")
            }
        } message: {
            Text("This archive has unsaved changes, do you want to close it without saving?")
        }
//        .onReceive(NotificationCenter.default.publisher(for: NSWindow.willCloseNotification)) { _ in
//            viewModel.postSavePromptClosure = {
//                dismissWindow()
//            }
//            viewModel.closeButton()
//        }
        .onReceive(NotificationCenter.default.publisher(for: NSApplication.willTerminateNotification)) { _ in
            // FIXME: This is pretty disgusting, we're replicating various parts of the view model's closeButton/saveButton

            defer { SettingsManager.shared.removeCacheDirectories() }

            guard let archive = viewModel.archive else { return }
            if !archive.dirty { return }

            let alert = NSAlert.init()
            alert.addButton(withTitle: "Save")
            alert.addButton(withTitle: "Save As")
            alert.addButton(withTitle: "Quit")
            alert.buttons.last?.hasDestructiveAction = true
            alert.informativeText = "This archive has unsaved changes, do you want to save them before quitting?"
            let response = alert.runModal()

            // runModal() has various return values, we are going to ignore any that aren't specific button presses
            switch response {
            case .alertFirstButtonReturn, .alertSecondButtonReturn, .alertThirdButtonReturn:
                break
            default:
                print("IGNORING: \(response)")
                return
            }

            let url = archive.URL
            var to = archive.URL
            let (format, filters, headerMap) = archive.metadataForSaving()
            let isNew = archive.isNew

            if response == .alertFirstButtonReturn && !archive.existsOnDisk || response == .alertSecondButtonReturn {
                // We need a filename and location from the user
                let (panel, pickerViewModel) = viewModel.prepareSaveAsPanel()

                if panel.runModal() == .OK {
                    if let destURL = panel.url {
                        to = destURL
                        archive.name = destURL.lastPathComponent
                        archive.format = pickerViewModel.format
                        archive.filters = pickerViewModel.format.defaultFilters
                    }
                }
            }

            let semaphore = DispatchSemaphore(value: 0)

            Task.detached(priority: .userInitiated) {
                defer { semaphore.signal() }

                let loader = libarchiveWrapper(url: url)

                do {
                    try await loader.writeArchive(headerMap: headerMap, to: to, format: format, filters: filters, skipRead: isNew)
                } catch {
                    print("FAILED TO SAVE ARCHIVE: \(error.localizedDescription)")
                }
            }

            semaphore.wait()

        }
    }
}

#Preview {
    MainWindowView()
}
