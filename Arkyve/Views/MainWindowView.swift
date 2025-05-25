//
//  MainWindowView.swift
//  Arkyve
//
//  Created by Chris Jones on 10/05/2024.
//

import SwiftUI

struct MainWindowView: View {
    @Environment(MainWindowViewModel.self) var viewModel
    
    func shutdownSaveRequest() {
        // NOTE: Try and keep this in sync with the view model's closeButton/saveButton
        print("shutdownSaveRequest")

        defer { SettingsManager.shared.removeCacheDirectories() }

        guard let archive = viewModel.archive, archive.dirty == true else {
            print("Archive not dirty, or not open, skipping.")
            return
        }

        let alert = NSAlert.init()
        let saveButton = alert.addButton(withTitle: "Save")
        alert.addButton(withTitle: "Save As")
        alert.addButton(withTitle: "Quit")
        alert.buttons.last?.hasDestructiveAction = true
        alert.informativeText = "This archive has unsaved changes, do you want to save them before quitting?"

        if !archive.format.canWrite {
            // We have to force the user to choose Save As since the archive is in a read-only format
            saveButton.isEnabled = false
        }
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
                    format = selectedArkyveFormat.libarchiveFormat
                    filters = selectedArkyveFormat.libarchiveFilters
                }
            } else {
                print("User cancelled Save As requester")
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
                print("Security Scoped Resource rejected")
                return
            }
            defer { to.stopAccessingSecurityScopedResource() }
            let loader = libarchiveWrapper(url: url)

            do {
                print("Saving archive")
                try await loader.writeArchive(headerMap: headerMap, to: to, format: format, filters: filters, skipRead: isNew)
            } catch {
                // NOTE: This cannot use AKError() because the main thread is currently blocked on us, and will be dead before any further runloop ticks
                print("FAILED TO SAVE ARCHIVE: \(error.localizedDescription)")
            }
        }

        semaphore.wait()
        archive.setClean() // We need to do this regardless of the save outcome, or we'll double-prompt on exit
    }

    var body: some View {
        // NOTE: This @Bindable is an ugly hack: https://www.hackingwithswift.com/books/ios-swiftui/sharing-observable-objects-through-swiftuis-environment
        @Bindable var viewModel = viewModel

        VStack(spacing: 0) {
            ErrorView()
                .environment(viewModel)
            if viewModel.archive != nil {
                TableView()
                    .environment(viewModel)
                    .disabled(viewModel.disableTableView)
            } else {
                // FIXME: This is a workaround until FB17404990 is resolved
                DummyTableView()
                    .environment(viewModel)
                    .disabled(viewModel.disableTableView)
            }
            Spacer(minLength: 0)
            StatusbarView()
                .environment(viewModel)
        }
        .focusable()
        .focusEffectDisabled()
        .onChange(of: viewModel.showErrors.error, initial: true) { old, new in
            // Nicely animate the error view appearing/disappearing
            withAnimation {
                viewModel.showErrors.show = new != nil
            }
        }
        .toolbar(id: "Main") {
            ToolbarContentView(viewModel: viewModel)
        }
        .navigationTitle(viewModel.navTitleText)
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
        .task {
            try? await Task.sleep(for: .seconds(5))
            if viewModel.archive == nil {
                MainWindowViewModel.noArchiveIsOpen.sendDonation()
            }
        }
    }
}

#Preview {
    @Previewable @State var viewModel = MainWindowViewModel()
    MainWindowView()
        .environment(viewModel)
        .task {
            viewModel.newButton()
        }
}
