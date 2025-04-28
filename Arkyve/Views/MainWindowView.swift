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
    
    func shutdownSaveRequest() {
        // FIXME: This is pretty disgusting, we're replicating various parts of the view model's closeButton/saveButton
        print("shutdownSaveRequest")

        defer { SettingsManager.shared.removeCacheDirectories() }

        guard let archive = viewModel.archive, archive.dirty == true else {
            print("Archive not dirty, or not open, skipping.")
            return
        }

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
            print("User chose to quit without saving, discarding archive")
            viewModel.closeArchive() // This is so we can call this method more than once and it's idempotent. We're quitting anyway
            return
        }

        let url = archive.URL
        var to = archive.URL
        var (format, filters, headerMap) = archive.metadataForSaving()
        let isNew = archive.isNew

        // FIXME: Re-work this to work the same way we now do save panels in SaveAs()
        // FIXME: In theory this is done, but it's untested
        if response == .alertFirstButtonReturn && !archive.existsOnDisk || response == .alertSecondButtonReturn {
            // User selected Save As, or they selected Save on an archive that we've never written to disk, so we will do a Save As
            let panel = viewModel.prepareSaveAsPanel()

            let innerResponse = panel.runModal()
            if innerResponse == .OK {
                if let destURL = panel.url {
                    guard let selectedArkyveFormat = ArkyveFormats.initFromUTType(panel.currentContentType) else {
                        print("Unable to detect which UTType the user selected in shutdownSaveRequest()")
                        return
                    }
                    to = destURL
                    archive.name = destURL.lastPathComponent // FIXME: Why?
                    format = selectedArkyveFormat.libarchiveFormat
                    filters = selectedArkyveFormat.libarchiveFilters
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

            if !to.startAccessingSecurityScopedResource() {
                return
            }
            defer { to.stopAccessingSecurityScopedResource() }
            let loader = libarchiveWrapper(url: url)

            do {
                try await loader.writeArchive(headerMap: headerMap, to: to, format: format, filters: filters, skipRead: isNew)
            } catch {
                // NOTE: This cannot use AKError() because the main thread is currently blocked on us, and will be dead before any further runloop ticks
                print("FAILED TO SAVE ARCHIVE: \(error.localizedDescription)")
            }
        }

        archive.setClean() // We need to do this regardless of the save outcome, or we'll double-prompt on exit
        semaphore.wait()
    }

    var body: some View {
        // NOTE: This @Bindable is an ugly hack: https://www.hackingwithswift.com/books/ios-swiftui/sharing-observable-objects-through-swiftuis-environment
        @Bindable var viewModel = viewModel

        VStack(spacing: 0) {
            ErrorView()
                .environment(viewModel)
            TableView(renameEntryFocus: $renameEntry)
                .environment(viewModel)
                .disabled(viewModel.archive == nil || viewModel.disableUI == true)
//                .hide(if: viewModel.archive == nil)
            Spacer(minLength: 0)
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
        // We need to react to both willTerminate and willClose because depending on whether the user closes
        // the window or quits the app, these will be called in different orders and the second iteration
        // typically doesn't work properly
        .onReceive(NotificationCenter.default.publisher(for: NSApplication.willTerminateNotification)) { value in
            print("applicationWillTerminate (SwiftUI)")
            shutdownSaveRequest()
        }
        .onReceive(NotificationCenter.default.publisher(for: NSWindow.willCloseNotification)) { value in
            // This gets called for each of our windows whether they are open or now, so we need to discard things like Log Viewer
            guard let window = value.object as? NSWindow, window.title == viewModel.navTitleText else { return }

            print("NSWindow willCloseNotification")
            shutdownSaveRequest()
        }
        .onOpenURL { url in
            AKTrace("System opened URL: \(url)")
            Task {
                await viewModel.openArchive(url: url)
            }
        }
    }
}

#Preview {
    MainWindowView()
}
