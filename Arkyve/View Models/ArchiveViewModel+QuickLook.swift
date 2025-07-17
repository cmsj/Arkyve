//
//  ArchiveViewModel+QuickLook.swift
//  Arkyve
//
//  Created by Chris Jones on 17/07/2025.
//

extension ArchiveViewModel {
    func resetQuickLook() {
        quickLookURL = nil
        quickLookItems = []
    }

    func extractForQuicklook() {
        let chosenEntries = entries.filter { selectedEntries.contains($0.id) }
        quickLookItems = []

        Task {
            do {
                let extractables = extractablesForEntries(chosenEntries)
                quickLookItems += try await extractSome(extractables: extractables, toFolder: cacheURL)
                if !quickLookItems.isEmpty {
                    quickLookURL = quickLookItems.first
                }
            } catch let error as ArkyveError {
                errors.err(error)
            } catch {
                errors.err(.init(.extract, msg: error.localizedDescription))
            }
        }
    }

    func nameForQuickLook(items: Set<ArchiveEntry.ID>?) -> String {
        let first = entries.first { entry in
            entry.id == items?.first
        }
        guard let first, items?.count == 1 else { return "" }
        return " \"\(first.name)\""
    }
}
