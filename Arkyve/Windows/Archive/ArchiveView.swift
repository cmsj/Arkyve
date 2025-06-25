//
//  ArchiveView.swift
//  Arkyve
//
//  Created by Chris Jones on 03/06/2025.
//

import SwiftUI

struct ArchiveView: View {
    var id: UUID
    @State var viewModel: ArchiveViewModel
    @EnvironmentObject var settingsManager: SettingsManager
    @Environment(\.dismissWindow) var dismissWindow
    @Environment(\.openWindow) var openWindow

    init(id: UUID) {
        self.id = id
        viewModel = ManagerManager.shared.findOrCreateVM(id)
    }

    var body: some View {
        VStack(spacing: 0) {
            ErrorView()
                .environment(viewModel)
            TableView()
                .environment(viewModel)
                .disabled(viewModel.disableTableView)
            Spacer(minLength: 0)
            StatusbarView()
                .environment(viewModel)
                .environmentObject(settingsManager)
        }
        .navigationTitle(viewModel.name)
        .navigationSubtitle(viewModel.navSubtitleText)
        .toolbar(id: "Main") {
            ToolbarContentView(viewModel: viewModel, settingsManager: settingsManager)
        }
        .focusedSceneValue(\.activeViewModel, viewModel)
        .onChange(of: viewModel.errors.error, initial: true) { old, new in
            // Nicely animate the error view appearing/disappearing
            withAnimation {
                viewModel.errors.show = new != nil
            }
        }
        .onAppear {
            dismissWindow(id: "splash")
        }
        // We need to react to both willTerminate and willClose because depending on whether the user closes
        // the window or quits the app, these will be called in different orders and the second iteration
        // typically doesn't work properly
        .onReceive(NotificationCenter.default.publisher(for: NSApplication.willTerminateNotification)) { value in
            ManagerManager.shared.isQuitting = true

            AKTrace("\(viewModel.id): NSApplication willTerminateNotification (dirty: \(viewModel.dirty))")
            if !viewModel.dirty {
                dismissWindow()
                ManagerManager.shared.removeVM(viewModel)
                return
            }

            let alert = NSAlert()
            let saveButton = alert.addButton(withTitle: "Save")
            alert.addButton(withTitle: "Save As...")
            alert.addButton(withTitle: "Close Archive")
            alert.buttons.last?.hasDestructiveAction = true
            alert.alertStyle = .critical
            alert.messageText = "Quit without saving?"
            alert.informativeText = "\(viewModel.name) has unsaved changes, do you want to quit without saving?"

            if !viewModel.format.canWrite {
                // Current archive can't be saved, so we'll disable the Save button
                saveButton.isEnabled = false
            }

            // If we have multiple windows open we will bring ourselves forward for the NSAlert to sit right on top of
            viewModel.window?.makeKeyAndOrderFront(nil)

            let sourceURL = viewModel.diskURL
            var destURL = viewModel.diskURL ?? viewModel.settingsManager.newArchiveURL
            var (format, filters, headerMap) = viewModel.metadataForSaving()
            let skipRead = viewModel.diskURL == nil
            let passphraseAtLoad = viewModel.passphraseAtLoad
            var passphraseToSave: String? = viewModel.passphraseToSave

            let response = alert.runModal()
            switch response {
            case .alertFirstButtonReturn, .alertSecondButtonReturn:
                // User has asked to Save/Save As which we will handle below
                break
            default:
                // For any other response we will let ourselves close
                dismissWindow()
                ManagerManager.shared.removeVM(viewModel)
                return
            }

            if response == .alertFirstButtonReturn && viewModel.diskURL == nil || response == .alertSecondButtonReturn {
                // User selected Save As, or they selected Save on an archive that we've never written to disk, so we will do a Save As
                let panel = viewModel.prepareSaveAsPanel()

                let innerResponse = panel.runModal()
                if innerResponse == .OK {
                    if let panelURL = panel.url {
                        guard let selectedArkyveFormat = ArkyveFormats.initFromUTType(panel.currentContentType) else {
                            print("Unable to detect which UTType the user selected in shutdownSaveRequest()")
                            return
                        }
                        destURL = panelURL
                        format = selectedArkyveFormat.libarchiveFormat
                        filters = selectedArkyveFormat.libarchiveFilters

                        try? viewModel.scopedURLManager.store(panelURL, forOperation: .writeArchive)
                    }
                } else {
                    print("User cancelled Save As requester")
                    dismissWindow()
                    ManagerManager.shared.removeVM(viewModel)
                    return
                }
            }

            if passphraseToSave != nil, passphraseToSave != "", !format.canEncrypt {
                // User has a passphrase set, but is saving in a format that can't be encrypted
                let alert = NSAlert()
                alert.icon = NSImage(systemSymbolName: "lock.slash", accessibilityDescription: nil)
                alert.messageText = "This archive cannot have a password"
                alert.informativeText = "Arkyve supports passwords only for Zip archives. If you proceed with saving as '\(format.description)' the password will be ignored."
                alert.addButton(withTitle: "Proceed")
                alert.addButton(withTitle: "Cancel")
                alert.buttons.first?.hasDestructiveAction = true

                let alertResponse = alert.runModal()
                if alertResponse == .alertFirstButtonReturn {
                    passphraseToSave = nil
                } else {
                    dismissWindow()
                    ManagerManager.shared.removeVM(viewModel)
                    return
                }
            }

            // We have a semaphore here because the main thread is trying to quit, but we have to wait for writeArchive()
            // to complete on a background thread. This allows us to dispatch the detached task and then wait for the
            // semaphore to be signalled after the archive has been written.
            let semaphore = DispatchSemaphore(value: 0)

            Task.detached(priority: .userInitiated) {
                // NOTE: WE MUST NOT ACCESS VIEWMODEL IN THIS TASK. MAIN THREAD IS BLOCKED ON THE SEMAPHORE WAITING FOR US.
                // ANY VIEWMODEL ACCESS TOUCHES MAIN THREAD AND WILL DEADLOCK US.
                print("In detached task")
                defer { semaphore.signal() }

                let loader = libarchiveWrapper(url: sourceURL, passphrase: passphraseAtLoad)

                do {
                    print("Saving archive")
                    try await loader.writeArchive(headerMap: headerMap, to: destURL, format: format, filters: filters, skipRead: skipRead, passphrase: passphraseToSave)
                } catch {
                    // NOTE: This cannot use AKError() because the main thread is currently blocked on us, and will be dead before any further runloop ticks
                    print("FAILED TO SAVE ARCHIVE: \(error.localizedDescription)")
                }
            }

            print("Waiting for semaphore...")
            semaphore.wait()

            viewModel.setClean() // We need to do this regardless of the save outcome, or we'll double-prompt on exit
            dismissWindow()
            ManagerManager.shared.removeVM(viewModel)
        }
        .onReceive(NotificationCenter.default.publisher(for: NSWindow.willCloseNotification)) { value in
            // This gets called for each of our windows whether they are open or now, so we need to discard things like Log Viewer
            guard let window = value.object as? NSWindow, window == viewModel.window else {
                print("Skipping \(value)")
                return
            }

            if ManagerManager.shared.isQuitting {
                print("App is quitting, skipping willCloseNotification")
                return
            }

            if viewModel.dirty {
                let alert = NSAlert()
                alert.addButton(withTitle: "Cancel")
                alert.addButton(withTitle: "Close Archive")
                alert.buttons.last?.hasDestructiveAction = true
                alert.alertStyle = .critical
                alert.messageText = "Close without saving?"
                alert.informativeText = "\(viewModel.name) has unsaved changes, do you want to close it without saving?"

                let response = alert.runModal()

                // runModal() has various return values, we are going to ignore any that aren't specific button presses
                switch response {
                case .alertFirstButtonReturn:
                    // User asked to cancel. This is going to be weird, but we're going to allow ourselves to close and then re-open ourselves
                    Task { @MainActor in
                        openWindow(id: "archive", value: viewModel.id)
                    }
                    // We must return here, so we don't trigger the removeVM below.
                    return
                default:
                    // Any other path means we're closing
                    break
                }
            }

            // Whatever happened, we are removing our VM
            AKTrace("\(viewModel.id): NSWindow.willCloseNotification scheduling VM for removal")
            Task { @MainActor in
                ManagerManager.shared.removeVM(viewModel)
            }
        }
    }
}
//
//#Preview {
//    ContentView()
//}
