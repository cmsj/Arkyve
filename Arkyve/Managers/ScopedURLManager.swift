//
//  ScopedURLManager.swift
//  Arkyve
//
//  Created by Chris Jones on 02/06/2025.
//

import Foundation
import Synchronization

struct URLBookmark: Codable, Hashable {
    let url: URL
    let bookmarkData: Data
}

final class ScopedURLManager: Sendable {
    let options: URL.BookmarkCreationOptions = [.withSecurityScope]
//                                                .securityScopeAllowOnlyReadAccess,
//                                                .withoutImplicitSecurityScope]
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
                urls.append(.init(url: url, bookmarkData: bookmarkData))
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

    static func bookmarkDataFromURL(_ url: URL) -> Data? {
        do {
            return try url.bookmarkData(options: [.withSecurityScope], includingResourceValuesForKeys: [])
        } catch {
            AKError("Unable to restore bookmark data for \(url): \(error.localizedDescription)")
            return nil
        }
    }

    static func urlFromBookmarkData(_ data: Data, for requestedURL: URL) -> URL? {
        var url: URL? = nil

        do {
            var stale = false
            url = try URL(resolvingBookmarkData: data, options: [.withSecurityScope], relativeTo: nil, bookmarkDataIsStale: &stale)
            if stale {
                guard let freshData = bookmarkDataFromURL(requestedURL) else {
                    throw ArkyveError(.scopedURLRefresh, msg: "Unable to refresh bookmark data for \(requestedURL)")
                }
                url = try URL(resolvingBookmarkData: freshData, options: [.withSecurityScope], relativeTo: nil, bookmarkDataIsStale: &stale)
            }
        } catch {
            AKError("Unable to fetch URL from bookmark data for \(requestedURL): \(error.localizedDescription)")
            return nil
        }

        return url
    }

    func bookmarkScopedURL(_ requestedURL: URL, forOperation: ArkyveError.ErrorKind) throws(ArkyveError) -> URL {
        AKTrace("\(baseID): Fetching bookmarked scoped URL for \(requestedURL)")
        let options: URL.BookmarkResolutionOptions = [.withSecurityScope]

        guard let storedBookmarkData = urlStore.withLock({ urlBookmarks in
            urlBookmarks.first { urlBookmark in
                urlBookmark.url == requestedURL
            }?.bookmarkData
        }) else {
            throw .init(.urlCache, msg: "Unable to find bookmark for URL: \(requestedURL)")
        }

        var stale = false
        let scopedURL: URL

        do {
            scopedURL = try URL(resolvingBookmarkData: storedBookmarkData,
                                options: options, relativeTo: nil,
                                bookmarkDataIsStale: &stale)
        } catch {
            throw .init(.urlCache, msg: "Unable to resolve bookmark for \(requestedURL)")
        }

        if stale {
            let _ = scopedURL.startAccessingSecurityScopedResource()
            try store(requestedURL, forOperation: forOperation)
        }

        _ = scopedURL.startAccessingSecurityScopedResource()
        return scopedURL
    }
}
