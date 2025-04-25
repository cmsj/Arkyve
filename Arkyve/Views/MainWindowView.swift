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
        .onReceive(NotificationCenter.default.publisher(for: NSWindow.willCloseNotification)) { value in
            guard let window = value.object as? NSWindow, window.title == viewModel.navTitleText else { return }

            AKTrace("Window close event, checking if the archive is unsaved")
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
            case .alertFirstButtonReturn, .alertSecondButtonReturn:
                // We only want to proceed if the Save or Save As buttons are chosen. Quit call fall through to the default
                break
            default:
                AKTrace("User chose to quit without saving")
                return
            }

            let url = archive.URL
            var to = archive.URL
            let (format, filters, headerMap) = archive.metadataForSaving()
            let isNew = archive.isNew

            if response == .alertFirstButtonReturn && !archive.existsOnDisk || response == .alertSecondButtonReturn {
                // We need a filename and location from the user
                let (panel, pickerViewModel) = viewModel.prepareSaveAsPanel()

                let innerResponse = panel.runModal()
                if innerResponse == .OK {
                    if let destURL = panel.url {
                        to = destURL
                        archive.name = destURL.lastPathComponent
                        archive.format = pickerViewModel.format
                        archive.filters = pickerViewModel.format.defaultFilters
                    }
                } else {
                    return
                }
            }

            // We have a semaphore here because the main thread is trying to quit, but we have to wait for writeArchive()
            // to complete on a background thread. This allows us to dispatch the detached task and then wait for the
            // semaphore to be signalled after the archive has been written.
            let semaphore = DispatchSemaphore(value: 0)

            Task.detached(priority: .userInitiated) {
                defer { semaphore.signal() }

                let loader = libarchiveWrapper(url: url)

                do {
                    try await loader.writeArchive(headerMap: headerMap, to: to, format: format, filters: filters, skipRead: isNew)
                } catch {
                    // NOTE: This cannot use AKError() because the main thread is currently blocked on us, and will be dead before any further runloop ticks
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
