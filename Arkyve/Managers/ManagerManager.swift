//
//  ManagerManager.swift
//  Arkyve
//
//  Created by Chris Jones on 03/06/2025.
//

import Foundation

@MainActor
protocol ManagerManagerProtocol: Sendable {
    func findOrCreateVM(_ id: UUID?) -> ArchiveViewModel
    func createVM(url: URL, truncateAt: Int?) -> ArchiveViewModel
    func removeVM(_ vm: ArchiveViewModel)
}

@Observable
@MainActor
final class ManagerManager: ManagerManagerProtocol, Sendable {
    /// Singleton instance
    static let shared = ManagerManager()

    private var vmStore: [ArchiveViewModel] = []
    private var cmStore: [CacheManager] = []
    private var sbmStore: [ScopedURLManager] = []

    var vmStoreIsEmpty: Bool {
        vmStore.count == 0
    }

    var isQuitting: Bool = false

    /// Create an ArchiveViewModel for a given URL
    /// - Parameter url: The URL that will be loaded
    /// - Returns: A new ArchievViewModel
    func createVM(url: URL, truncateAt: Int? = nil) -> ArchiveViewModel {
        let id = UUID()
        AKTrace("\(id): createVM(url:): \(url)")
        let scopedURLManager = sbmForID(id)
        try? scopedURLManager.store(url, forOperation: .readArchive)
        let cacheManager = cmForID(id)

        let vm = createVM(id: id, settingsManager: .shared, scopedURLManager: scopedURLManager, cacheManager: cacheManager, diskURL: url, truncateAt: truncateAt)
        vm.diskURL = url
        return vm
    }
    
    /// Clean up and destroy an ArchiveViewModel
    /// - Parameter vm: The view model to delete
    func removeVM(_ vm: ArchiveViewModel) {
        let id = vm.id
        AKTrace("\(id): removeVM")

        vmStore.removeAll { $0 === vm }

        sbmStore.removeAll { $0.baseID == id }

        vm.cacheManager.removeCacheDirectories()
        cmStore.removeAll { $0.baseID == id }

        if isQuitting && vmStoreIsEmpty {
            // We are terminating and we've run out of view models, let's clear the drag&drop cache/SBM
            print("ManagerManager: App termination detected, clearing drag&drop cache/SBM")
            
            CacheManager.dropCache.removeCacheDirectories()
            ScopedURLManager.dropSBM.clear()
        }
    }
    
    /// Return a previous ArchiveViewModel for a given ID, or create a new one for it
    /// - Parameter possibleID: A UUID representing the view model
    /// - Returns: A view model
    func findOrCreateVM(_ possibleID: UUID? = nil) -> ArchiveViewModel {
        var id: UUID

        if let possibleID {
            id = possibleID
        } else {
            id = UUID()
            AKTrace("\(id): vmForID: Creating new ID")
        }
        if let vm = vmStore.first(where: { $0.id == id }) {
            AKTrace("\(id): vmForID: Found VM")
            return vm
        } else {
            AKTrace("\(id): vmForID: Creating new VM")
            let vm = createVM(id: id, scopedURLManager: sbmForID(id), cacheManager: cmForID(id))
            return vm
        }
    }

    // MARK: - Private API
    private func createVM(id: UUID, settingsManager: SettingsManager = SettingsManager.shared,
                          scopedURLManager: ScopedURLManager,
                          cacheManager: CacheManager,
                          diskURL: URL? = nil, truncateAt: Int? = nil) -> ArchiveViewModel {

        let vm = ArchiveViewModel(id: id,
                                  settingsManager: settingsManager,
                                  scopedURLManager: scopedURLManager,
                                  cacheManager: cacheManager,
                                  diskURL: diskURL,
                                  truncateAt: truncateAt)
        AKTrace("\(id): createVM(id:) storing ArchiveViewModel")
        vmStore.append(vm)
        return vm
    }

    // MARK: - CacheManager
    private func createCM(id: UUID) -> CacheManager {
        let cm = CacheManager(for: id)
        cmStore.append(cm)
        return cm
    }

    private func removeCM(_ cm: CacheManager) {
        cmStore.removeAll { $0.baseID == cm.baseID }
    }

    private func cmForID(_ id: UUID) -> CacheManager {
        if let cm = cmStore.first(where: { $0.baseID == id }) {
            return cm
        } else {
            let cm = createCM(id: id)
            return cm
        }
    }

    // MARK: - ScopedURLManager
    private func createSBM(id: UUID) -> ScopedURLManager {
        let sbm = ScopedURLManager(for: id)
        sbmStore.append(sbm)
        return sbm
    }

    private func removeSBM(_ sbm: ScopedURLManager) {
        sbmStore.removeAll { $0.baseID == sbm.baseID }
    }

    private func sbmForID(_ id: UUID) -> ScopedURLManager {
        if let sbm = sbmStore.first(where: { $0.baseID == id }) {
            return sbm
        } else {
            let sbm = createSBM(id: id)
            return sbm
        }
    }
}
