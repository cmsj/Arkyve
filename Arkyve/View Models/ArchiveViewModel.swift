//
//  ArchiveViewModel.swift
//  Arkyve
//
//  Created by Chris Jones on 03/06/2025.
//

import SwiftUI

@MainActor
func openArchiveFromURL(_ requestedURL: URLBookmark, openWindow: OpenWindowAction) {
    var vm: ArchiveViewModel?

    guard let url = ScopedURLManager.urlFromBookmarkData(requestedURL.bookmarkData, for: requestedURL.url) else {
        AKError("Unable to restore URL from bookmark data")
        return
    }

    let urlBookmark = URLBookmark(url: url, bookmarkData: requestedURL.bookmarkData)

    vm = ManagerManager.shared.findVM(url)

    if vm == nil {
        vm = ManagerManager.shared.createVM(url: urlBookmark.url)
        SettingsManager.shared.addRecent(urlBookmark)
    }
    openWindow(id: "archive", value: vm!.id)
}

@MainActor
@discardableResult func openArchiveFromPanel(openWindow: OpenWindowAction, wasSplash: Bool = false) -> Bool {
    let panel = NSOpenPanel()
    panel.canChooseFiles = true
    panel.canChooseDirectories = false
    panel.allowsMultipleSelection = true
    panel.allowedContentTypes = ArkyveFormats.utTypes

    if panel.runModal() == .OK {
        if let url = panel.url {
            AKTrace("Open Menu: \(url)")
            if let bookmarkData = ScopedURLManager.bookmarkDataFromURL(url) {
                let bookmark = URLBookmark(url: url, bookmarkData: bookmarkData)
                openArchiveFromURL(bookmark, openWindow: openWindow)
                return true
            } else {
                AKError("Unable to open archive from panel URL due to bookmark creation failure")
            }
        }
    }

    // Something didn't go right, bring back the splash window
    if wasSplash {
        openWindow(id: "splash")
    }

    return false
}

@Observable
@MainActor
final class ArchiveViewModel: Identifiable, WindowAccessorDelegate {
    let id: UUID

    // MARK: - Managers
    let settingsManager: SettingsManager
    let scopedURLManager: ScopedURLManager
    let cacheManager: CacheManager
    var errors: ErrorManager = ErrorManager()
    let tips = TipsManager()

    // MARK: - Archive properties
    var diskURL: URL?
    var cacheURL: URL
    var name: String
    var entries: [ArchiveEntry] = []

    // This whole thing is ridiculous. We need to store the passphrase used to load the archive and also store whatever is typed into the password sheet.
    // It's also ridiculous to have a hasEncryptedEntries that serves almost no purpose, but that may be unavoidable.
    var hasEncryptedEntries: Bool = false
    var passphraseAtLoad: String = ""
    var passphraseToSave: String = ""

    var root = ArchiveEntry(isRoot: true)
    var format: libarchiveFormat = SettingsManager().newArchiveFormat.libarchiveFormat
    var filters: [libarchiveFilter] = SettingsManager().newArchiveFormat.libarchiveFilters
    private(set) var dirty: Bool = false
    var truncateAt: Int? = nil
    private(set) var didTruncate: Bool = false
    var offerTopDirectory: Bool {
        // Should extraction offer to create a directory?
        switch root.children.count {
        case 0, 1:
            return false
        default:
            return true
        }
    }

    // MARK: - UI properties
    weak var window: NSWindow? = nil
    var selectedEntries = Set<ArchiveEntry.ID>()
    var focusedEntry: UUID? = nil

    var searchQuery: String = ""
    var searchPresented: Bool = false

    var sortOrder = [KeyPathComparator(\ArchiveEntry.name)]
    var quickLookURL: URL?
    var quickLookItems: [URL] = []

    var progressTask: Task<Void, Never>? = nil
    var isCancelling: Bool = false

    // MARK: - Disable various parts of the UI
    var disableUI: Bool = false {
        didSet { print("UI DISABLED: \(disableUI)") }
    }

    var disableNew: Bool { disableUI }
    var disableOpen: Bool { disableUI }
    var disableCloseWindow: Bool { disableUI }
    var disableAdd: Bool { disableUI }
    var disableRevert: Bool { disableUI || dirty != true || diskURL == nil }
    var disableCloseArchive: Bool { disableUI }
    var disableSave: Bool { disableUI || dirty != true || format.canWrite == false }
    var disableSaveAs: Bool { disableUI }
    var disableQuicklook: Bool { disableUI || selectedEntries.isEmpty }
    var disableExtract: Bool { disableUI || selectedEntries.isEmpty }
    var disableExtractAll: Bool { disableUI || entries.count == 0 }
    var disableRename: Bool { disableUI || selectedEntries.count != 1 }
    var disableDelete: Bool { disableUI || selectedEntries.isEmpty }
    var disableNewFolder: Bool { disableUI }
    var disableExpandCollapse: Bool { disableUI }
    var disableTableView: Bool { disableUI }
    var disableShare: Bool { disableUI || selectedEntries.isEmpty }
    var disableSearchMenu: Bool { disableUI }

    var lockSymbol: String {
        if hasEncryptedEntries {
            if format == .ZIP {
                return "lock"
            } else {
                return "lock.slash"
            }
        }
        return "lock.open"
    }
    var lockHelp: String {
        if hasEncryptedEntries {
            if format == .ZIP {
                return "Archive is encrypted"
            } else {
                return "Unsupported archive encryption"
            }
        }
        return "Archive is not encrypted"
    }

    // MARK: - Dynamic UI text
    var navSubtitleText: String { "\(dirty ? "(Unsaved)" : "")" }
    var statusBarText: String {
        if isCancelling {
            return "Cancelling.."
        }

        if progressTask != nil {
            return "Working..."
        }

        let text: String
        if selectedEntries.count > 0 {
            text = "\(selectedEntries.count) of \(entries.count) selected"
        } else {
            text = String(localized:"\(entries.count) items")
        }
        return text
    }

    init(id: UUID, settingsManager: SettingsManager, scopedURLManager: ScopedURLManager, cacheManager: CacheManager, diskURL: URL? = nil, truncateAt: Int? = nil) {
        self.settingsManager = settingsManager
        self.scopedURLManager = scopedURLManager
        self.cacheManager = cacheManager

        let name = diskURL?.lastPathComponent ?? settingsManager.newArchiveFilename

        self.id = id
        self.diskURL = diskURL
        self.name = name
        self.cacheURL =  cacheManager.urlForItem(cacheType: .read, itemName: name)
        self.truncateAt = truncateAt

        if let diskURL {
            // We have a URL, so we can immediately load our archive
            AKTrace("\(id): ArchiveViewmodel initialised with a disk URL, loading...")
            openArchiveWithTask(url: diskURL, truncateAt: truncateAt)
        } else {
            AKTrace("\(id): ArchiveViewModel initialized without a disk URL")
        }
    }

    deinit {
        AKTrace("\(id): ArchiveViewModel deinit")
    }

    func reinit(for url: URL) {
        let name = url.lastPathComponent
        self.diskURL = url
        self.name = name
        openArchiveWithTask(url: url)
    }

    func setDirty(_ dirty: Bool = true) {
        AKTrace("Marking archive \(dirty ? "dirty" : "clean")")
        self.dirty = dirty
    }

    func setClean() {
        setDirty(false)
    }

    func openArchiveWithTask(url: URL, truncateAt: Int? = nil) {
        AKTrace("\(id): ArchiveViewModel dispatching libarchive read for \(url)")

        errors.clear()

        withProgressTask { [self] in
            var didFail = true

            do {
                let (archiveFormat, archiveFilters, entries, root, didTruncate) = try await libarchiveWrapper.loadArchive(at: url, entryLimit: truncateAt ?? -1, passphrase: passphraseAtLoad)
                didFail = false

                if archiveFormat.canWrite == false {
                    ReadOnlyStatus.event.sendDonation()
                }

                Task { @MainActor in
                    self.format = archiveFormat
                    self.filters = archiveFilters
                    self.entries = entries
                    self.root = root
                    self.didTruncate = didTruncate
                    if let _ = entries.first(where: { $0.isEncrypted }) {
                        self.hasEncryptedEntries = true
                    }

                    // Ensure our UI is consistent
                    self.setClean()
                    sort()

                    // Expand folders per our settings
                    switch settingsManager.folderExpansion {
                    case .always:
                        self.entries.forEach { $0.isExpanded = true }
                    case .oneOnly:
                        if root.children.count == 1, root.children.first?.type == .directory {
                            root.children.first?.isExpanded = true
                        }
                    case .never:
                        break
                    }
                }
            } catch let error as ArkyveError {
                errors.err(error)
            } catch {
                errors.err(.init(.openArchive, msg: error.localizedDescription))
            }

            if didFail {
                Task { @MainActor in
                    self.disableUI = true
                }
            }
        }
    }

    func waitForArchiveProgressTask() async throws {
        NSLog("waitForArchiveProgressTask(): Sleeping until archive is loaded...")
        var sleepIndex = 0
        var timeoutIndex = 0
        while progressTask != nil {
            try await Task.sleep(for: .seconds(0.5))
            sleepIndex += 1
            if sleepIndex > 20 {
                NSLog("waitForArchiveProgressTask(): Still sleeping...")
                sleepIndex = 0
                timeoutIndex += 1
            }
            if timeoutIndex > 30 {
                NSLog("waitForArchiveProgressTask(): Giving up sleep after 5 minutes...")
                throw ArkyveError(.extract, msg: "Timed out waiting for task to complete")
            }
        }
        NSLog("waitForArchiveProgressTask(): Waking up after task completed.")
        if let error = errors.error {
            throw error
        }
    }

    // MARK: - Archive navigation
    func entryForID(_ id: UUID) -> ArchiveEntry? {
        if id == root.id { return root }
        return entries.first { $0.id == id }
    }

    func parentForEntry(_ entry: ArchiveEntry) -> ArchiveEntry? {
        return entries.first(where: { item in
            item.children.contains { $0.id == entry.id }
        })
    }

    func rootEntryName() -> String? {
        NSLog("rootEntryName(): \(root.children.count) children, first path: \(root.children.first?.path ?? "UNKNOWN")")
        if root.children.count > 1 { return nil }
        return root.children.first?.pathComponents.last
    }

    func pathList() -> [String] {
        return entries.map { $0.path }
    }
}
