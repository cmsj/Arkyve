//
//  ScopedURLManager.swift
//  Arkyve
//
//  Created by Chris Jones on 02/06/2025.
//

import Foundation
import Synchronization

struct Bookmark {
    let data: Data
    let options: URL.BookmarkCreationOptions
}

struct URLBookmark {
    let url: URL
    let bookmark: Bookmark
}

final class ScopedURLManager: Sendable {
    let options: URL.BookmarkCreationOptions = [.withSecurityScope,
                                                .securityScopeAllowOnlyReadAccess,
                                                .withoutImplicitSecurityScope]
    let urlStore: Mutex<[URLBookmark]> = .init([])
    let baseID: UUID

    static let dropSBM = ScopedURLManager(for: UUID())

    init(for baseID: UUID) {
        self.baseID = baseID
    }

    deinit {
        AKTrace("\(baseID): SBM deinit")
        clear()
    }

    func store(_ urls: [URL], forOperation: ArkyveError.ErrorKind) throws(ArkyveError) {
        for url in urls {
            try store(url, forOperation: forOperation)
        }
    }

    func store(_ url: URL, forOperation: ArkyveError.ErrorKind) throws(ArkyveError) {
        do {
            try urlStore.withLock { urls in
                if urls.first(where: { $0.url == url }) != nil {
                    AKTrace("\(baseID): Skipping bookmark scoping of already-known URL: \(url) (\(forOperation))")
                    return
                }
                let result = url.startAccessingSecurityScopedResource()
                let bookmarkData = try url.bookmarkData(options: options, includingResourceValuesForKeys: [])
                urls.append(.init(url: url, bookmark: Bookmark(data: bookmarkData, options: options)))
                AKTrace("\(baseID): Stored security scope for: \(url) (doing: \(forOperation))")
                if result {
                    AKTrace("\(baseID): Started security scope for: \(url) (doing: \(forOperation))")
                }
            }
        } catch {
            throw ArkyveError(.urlCache, msg: error.localizedDescription)
        }
    }

    func remove(_ url: URL) {
        AKTrace("\(baseID): Removing security scope for: \(url)")
        urlStore.withLock { urls in
            urls.removeAll { $0.url == url }
            url.stopAccessingSecurityScopedResource()
        }
    }

    func clear() {
        AKTrace("\(baseID): Clearing security scoped URLs")
        urlStore.withLock { urls in
            urls.forEach { urlBookmark in
                urlBookmark.url.stopAccessingSecurityScopedResource()
            }
            urls.removeAll()
        }
    }

    func bookmarkScopedURL(_ requestedURL: URL) throws(ArkyveError) -> URL {
        AKTrace("\(baseID): Fetching bookmarked scoped URL for \(requestedURL)")
        var options = URL.BookmarkResolutionOptions()

        guard let storedBookmark = urlStore.withLock({ urlBookmarks in
            urlBookmarks.first { urlBookmark in
                urlBookmark.url == requestedURL
            }?.bookmark
        }) else {
            throw .init(.urlCache, msg: "Unable to find bookmark for URL: \(requestedURL)")
        }

        if storedBookmark.options.contains(.withSecurityScope) {
            options.insert(.withSecurityScope)
        }
        if storedBookmark.options.contains(.withoutImplicitSecurityScope) {
            options.insert(.withoutImplicitStartAccessing)
        }

        var stale = false
        let scopedURL: URL

        do {
            scopedURL = try URL(resolvingBookmarkData: storedBookmark.data,
                                options: options, relativeTo: nil,
                                bookmarkDataIsStale: &stale)
        } catch {
            throw .init(.urlCache, msg: "Unable to resolve bookmark for \(requestedURL)")
        }

        if stale {
            let _ = scopedURL.startAccessingSecurityScopedResource()
            try store(requestedURL, forOperation: .scopedURLRefresh)
        }

        _ = scopedURL.startAccessingSecurityScopedResource()
        return scopedURL
    }
}
