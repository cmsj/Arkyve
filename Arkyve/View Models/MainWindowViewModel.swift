//
//  MainWindowViewModel.swift
//  Arkyve
//
//  Created by Chris Jones on 04/06/2024.
//

import SwiftUI
import System
import TipKit

@Observable
@MainActor
class MainWindowViewModel {
    var archive: Archive? = nil

    var selectedEntries = Set<ArchiveEntry.ID>()
    var focusedEntry: UUID? = nil
    var sortOrder = [KeyPathComparator(\ArchiveEntry.name)]
    var quickLookURL: URL?
    var quickLookItems: [URL] = []

    var progressTask: Task<Void, Never>? = nil
    var progress: ArkyveProgressState = .idle

    var showErrors: ShowErrors = ShowErrors()

    // MARK: - Save prompt
    var showSavePrompt = false
    var postSavePromptClosure: (() -> Void)? = nil

    // MARK: - Disable various parts of the UI
    var disableUI: Bool = false

    var disableNew: Bool { disableUI }
    var disableOpen: Bool { disableUI }
    var disableAdd: Bool { disableUI || archive == nil }
    var disableRevert: Bool { disableUI || archive?.dirty != true || archive?.existsOnDisk != true }
    var disableClose: Bool { disableUI || archive == nil }
    var disableSave: Bool { disableUI || archive?.dirty != true || archive?.format.canWrite == false }
    var disableSaveAs: Bool { disableUI || archive == nil }
    var disableQuicklook: Bool { disableUI || selectedEntries.isEmpty }
    var disableExtract: Bool { disableUI || selectedEntries.isEmpty }
    var disableExtractAll: Bool { disableUI || archive == nil || archive?.entries.count == 0 }
    var disableRename: Bool { disableUI || selectedEntries.count != 1 }
    var disableDelete: Bool { disableUI || selectedEntries.isEmpty }
    var disableNewFolder: Bool { disableUI || archive == nil }
    var disableExpandCollapse: Bool { disableUI || archive == nil }
    var disableTableView: Bool { disableUI || archive == nil }
    var disableShare: Bool { disableUI || selectedEntries.isEmpty }

    // MARK: - Dynamic UI text
    let navTitleText = "Arkyve"
    var navSubtitleText: String {
        guard let archive else { return "" }
        return "\(archive.name) \(archive.dirty ? "(Unsaved)" : "")"
    }
    var statusBarText: String {
        if progressTask != nil { return "Working..." }

        guard let archive else { return "No archive open" }
        var text = String(localized:"\(archive.entries.count) items")
        if !archive.format.canWrite { text += " (read-only)" }
        return text
    }

    // MARK: - Tips
    struct TipsStore {
        var readOnlyStatus = ReadOnlyStatus()
    }
    static let didOpenReadOnlyEvent = Tips.Event(id: "didOpenReadOnly")
    let tips = TipsStore()

    // MARK: - Progress indicator
    func setProgress(_ tp: TaskProgress) {
        switch tp.status {
        case .running(let units):
            if let total = units.total {
                progress = .determinate(Double(units.completed) / Double(total))
            } else {
                progress = .indeterminate
            }
        case .finished, .failed(_):
            progress = .idle
        }
    }
}
