//
//  MWVM+Operations.swift
//  Arkyve
//
//  Created by Chris Jones on 07/05/2025.
//

import AppKit

extension MainWindowViewModel {
    // It's unusual to have something throwing here, but we want to
    // surface a rename failure up to the UI so it can keep the item focused
    func renameEntry(of entry: ArchiveEntry) throws(ArkyveError) {
        guard let archive else { return }
        do {
            try archive.processEntryRename(entry)
            if showErrors.error?.kind == .rename {
                showErrors.error = nil
            }
            sort()
        } catch {
            showErrors.err(error)
            throw error
        }
    }

    func sort() {
        guard let archive else { return }

        archive.sort(using: sortOrder)
    }

    func setArchiveDirty() {
        guard let archive else { return }
        archive.setDirty()
    }

    func newArchive() {
        showErrors.clear()

        archive = Archive()
        selectedEntries = []
        quickLookURL = nil
        quickLookItems = []
    }

    func openArchive(url: URL) async {
        showErrors.clear()

        let loader = libarchiveWrapper(url: url)
        self.disableUI = true
        defer { self.disableUI = false }

        progressTask = Task {
            defer { progressTask = nil }

            do {
                archive = try await loader.loadArchive()
                sort()

                if archive?.format.asArkyveFormat?.canWrite == false {
                    Self.didOpenReadOnlyEvent.sendDonation()
                }
            } catch let error as ArkyveError {
                showErrors.err(error)
            } catch {
                showErrors.err(ArkyveError.init(.openArchive, msg: error.localizedDescription))
            }
        }
    }

    func closeArchive() {
        showErrors.clear()
        guard archive != nil else { return }

        archive = nil
        selectedEntries = []
        quickLookURL = nil
        quickLookItems = []
    }

    func saveArchive(to: URL, overrideFormat: libarchiveFormat = .Unknown, overrideFilters: [libarchiveFilter] = [.None]) async {
        guard let archive else { return }
        showErrors.clear()

        let loader = libarchiveWrapper(url: archive.URL)
        self.disableUI = true
        defer { self.disableUI = false }

        progressTask = Task {
            defer { progressTask = nil }

            let (format, filters, headerMap) = archive.metadataForSaving(overrideFormat: overrideFormat, overrideFilters: overrideFilters)

            do {
                try await loader.writeArchive(headerMap: headerMap, to: to, format: format, filters: filters, skipRead: archive.isNew)
                archive.didSave(to: to, format: format, filters: filters)
            } catch let error as ArkyveError {
                showErrors.err(error)
            } catch {
                showErrors.err(ArkyveError(.writeArchive, msg: error.localizedDescription))
            }
        }
    }

    func copyArchive(to: URL) {
        guard let archive else { return }

        do {
            AKTrace("Copying \(archive.URL) to \(to)")
            try FileManager.default.copyItem(at: archive.URL, to: to)
            archive.didSave(to: to, format: archive.format, filters: archive.filters)
        } catch {
            showErrors.err(.init(.writeArchive, msg: error.localizedDescription))
        }
    }

    func extractEntries(_ chosenEntries: [ArchiveEntry], archive: Archive, destURL: URL, retainFullPath: Bool) {
        var extractableEntries: [ArchiveEntryExtractable] = []
        var overwriteAll = false

        // Filter out anything that already exists, but that the user doesn't want to overwrite
        entryLoop: for entry in chosenEntries {
            let fullDestURL = destURL.appending(path: retainFullPath ? entry.path : entry.name)

            // Check if fullDestURL exists, if it does, show an alert to ask the user if we should overwrite
            let fullDestExists = try? fullDestURL.checkResourceIsReachable()
            if !overwriteAll && fullDestExists == true {
                let alert = NSAlert()
                alert.addButton(withTitle: "Replace")
                alert.addButton(withTitle: "Replace All")
                alert.addButton(withTitle: "Skip")

                alert.buttons[0].hasDestructiveAction = true
                alert.buttons[1].hasDestructiveAction = true
                alert.messageText = "File already exists"
                alert.informativeText = "Do you want to replace \(fullDestURL.path)"
                alert.alertStyle = .critical

                let response = alert.runModal()
                switch response {
                case .alertFirstButtonReturn:
                    break
                case .alertSecondButtonReturn:
                    overwriteAll = true
                case .alertThirdButtonReturn:
                    continue entryLoop
                default:
                    AKError("Unknown response \(response.rawValue)")
                    return
                }
            }

            let extractableEntry = entry.asExtractable(for: archive)
            extractableEntries.append(extractableEntry)
        }

        if extractableEntries.count == 0 {
            // We have nothing left to do
            return
        }

        progressTask = Task {
            defer { progressTask = nil }

            self.disableUI = true
            defer { self.disableUI = false }

            let loader = libarchiveWrapper(url: archive.URL)

            do {
                let _ = try await loader.extract(extractableEntries, toFolder: destURL, retainFullPath: retainFullPath, archiveIsNew: !archive.existsOnDisk)
            } catch let error as ArkyveError {
                showErrors.err(error)
            } catch {
                showErrors.err(.init(.extract, msg: error.localizedDescription))
            }
        }
    }

    func resetQuickLook() {
        self.quickLookURL = nil
        self.quickLookItems = []
    }

    func extractForQuicklook() {
        guard let archive else { return }

        let chosenEntries = archive.entries.filter { selectedEntries.contains($0.id) }
        let extractableEntries: [ArchiveEntryExtractable] = chosenEntries.map { $0.asExtractable(for: archive) }

        quickLookItems = []

        Task {
            let loader = libarchiveWrapper(url: archive.URL)

            do {
                quickLookItems += try await loader.extract(extractableEntries, toFolder: archive.cacheURL, archiveIsNew: !archive.existsOnDisk)
                if !quickLookItems.isEmpty {
                    quickLookURL = quickLookItems.first
                }
            } catch let error as ArkyveError {
                showErrors.err(error)
            } catch {
                showErrors.err(.init(.extract, msg: error.localizedDescription))
            }
        }
    }

    // FIXME: Do the following two functions belong here?
    func nameForQuickLook(items: Set<ArchiveEntry.ID>?) -> String {
        let first = archive?.entries.first { entry in
            entry.id == items?.first
        }
        guard let first, items?.count == 1 else { return "" }
        return " \"\(first.name)\""
    }

    func extractablesForSelected() -> [ArchiveEntryExtractable] {
        guard let archive else { return [] }

        let extractables = selectedEntries.compactMap { entryID in
            if let first = archive.entries.first(where: { $0.id == entryID }) {
                return first.asExtractable(for: archive)
            } else {
                return nil
            }
        }

        return extractables
    }
}
