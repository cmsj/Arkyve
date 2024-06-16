//
//  Archive.swift
//  ZipZap
//
//  Created by Chris Jones on 10/05/2024.
//

import Foundation
import os

enum ArchiveError: Error {
    case ArchiveOpenError(String)
    case ArchiveEntriesError(String)
    case ArchiveExtractError(String)
}

enum ArchiveEntriesAction {
    case Continue
    case Break
}

enum ArchiveFormat: Int32 {
    case Unknown = 0x0
    case CPIO = 0x10000
    case CPIO_POSIX = 0x10001
    case CPIO_BIN_LE = 0x10002
    case CPIO_BIN_BE = 0x10003
    case CPIO_SVR4_NOCRC = 0x10004
    case CPIO_SVR4_CRC = 0x10005
    case CPIO_AFIO_LARGE = 0x10006
    case CPIO_PWB = 0x10007
    case SHAR = 0x20000
    case SHAR_BASE = 0x20001
    case SHAR_DUMP = 0x20002
    case TAR = 0x30000
    case TAR_USTAR = 0x30001
    case TAR_PAX_INTERCHANGE = 0x30002
    case TAR_PAX_RESTRICTED = 0x30003
    case TAR_GNUTAR = 0x30004
    case ISO9660 = 0x40000
    case ISO9660_RR = 0x40001
    case ZIP = 0x50000
    case Empty = 0x60000
    case AR = 0x70000
    case AR_GNU = 0x70001
    case AR_BSD = 0x70002
    case MTREE = 0x80000
    case RAW = 0x90000
    case XAR = 0xA0000
    case LHA = 0xB0000
    case CAB = 0xC0000
    case RAR = 0xD0000
    case _7ZIP = 0xE0000
    case WARC = 0xF0000
    case RAR_V5 = 0x100000
}

enum ArchiveFilter: Int32 {
    case None = 0
    case GZip
    case BZip2
    case Compress
    case Program
    case LZMA
    case XZ
    case UU
    case RPM
    case LZIP
    case LRZIP
    case LZOP
    case GRZIP
    case LZ4
    case ZSTD
}

// MARK: Sorting
extension Archive {
    // Sort our entries and return a new value, munging keypaths appropriately for the various fields of ArchiveEntry which need to be passed to Table as Strings, but don't sort well as Strings (ie dates)
    func sort(using: [KeyPathComparator<ArchiveEntry>]) {
        guard let sortDetails = using.first else { return }
        var newSort: KeyPathComparator<ArchiveEntry>

        switch (sortDetails.keyPath) {
        case \ArchiveEntry.mtime.userFormatted:
            newSort = KeyPathComparator(\ArchiveEntry.mtime, order: sortDetails.order)
        case \ArchiveEntry.ctime.userFormatted:
            newSort = KeyPathComparator(\ArchiveEntry.ctime, order: sortDetails.order)
        case \ArchiveEntry.atime.userFormatted:
            newSort = KeyPathComparator(\ArchiveEntry.atime, order: sortDetails.order)
        case \ArchiveEntry.btime.userFormatted:
            newSort = KeyPathComparator(\ArchiveEntry.btime, order: sortDetails.order)
        default:
            newSort = sortDetails
        }

        // FIXME: This should be sorting the tree, not the array
        self.entries.sort(using: [newSort])
    }
}

// MARK: Libarchive wrappers
//extension Archive {
//    func libarchive_open() throws {
//        if self.fd >= 0 {
//            lseek(self.fd, 0, SEEK_SET)
//        }
//
//        // Prepare libarchive's data structure
//        archive = archive_read_new()
//        if archive == nil {
//            throw ArchiveError.ArchiveOpenError("Unable to allocate archive memory")
//        }
//        archive_read_support_filter_all(archive)
//        archive_read_support_format_all(archive)
//
//        Self.logger.trace("Opening: \(self.path)")
//        self.fd = Darwin.open(self.path, O_RDONLY)
//        if self.fd < 0 {
//            libarchive_close()
//            throw ArchiveError.ArchiveOpenError("Unable to open \(self.path): \(errno)")
//        }
//
//        let ptr = archive_read_open_fd(archive, self.fd, 10240)
//        if ptr != ARCHIVE_OK {
//            let errStr = String(cString: archive_error_string(archive))
//            libarchive_close()
//            throw ArchiveError.ArchiveOpenError("Unable to open archive (\(ptr)): \(errStr)")
//        }
//    }
//
//    func libarchive_close() {
//        guard self.archive != nil else { return }
//        archive_read_free(archive)
//        archive = nil
//    }
//
//    func libarchive_entries(_ closure: (OpaquePointer?) throws -> ArchiveEntriesAction) throws {
//        guard self.archive != nil else {
//            throw ArchiveError.ArchiveEntriesError("libarchive_entries() called on a nil archive")
//        }
//
//        var entry: OpaquePointer?
//        Self.logger.trace("Walking archive headers...")
//        while (archive_read_next_header(self.archive, &entry) == ARCHIVE_OK) {
//            if try closure(entry) == .Break {
//                break
//            }
//        }
//    }
//
//    func libarchive_entry_path(_ entry: OpaquePointer?) -> String? {
//        var string: String? = nil
//
//        if let cString = archive_entry_pathname(entry) {
//            string = String(cString: cString)
//        }
//
//        // Lots of archives include trailing slashes on their path names, which is annoying and unnecessary.
//        if string != nil && string?.last == "/" {
//            string = String(string!.dropLast())
//        }
//
//        return string
//    }
//
//    func libarchive_entry_data(_ entry: OpaquePointer?) -> Data {
//        let size = Int(archive_entry_size(entry))
//        let rawData = UnsafeMutablePointer<UInt8>.allocate(capacity: size)
//
//        Self.logger.trace("Reading entry data (\(size) bytes)")
//        archive_read_data(self.archive, rawData, size)
//
//        return Data(bytes: rawData, count: size)
//    }
//}

@Observable
class Archive {
    let logger: Logger
    let queue = DispatchQueue(label: UUID().uuidString, qos: .userInitiated)

    var URL: URL
    var path: String
    var name: String
    var entries: [ArchiveEntry] = []
    var root: ArchiveEntry!
    var error: String? = nil
    var log: [ArchiveLogEntry] = []
    var format: ArchiveFormat = .Unknown
    var filters: [ArchiveFilter] = []
    var cacheURL: URL

    init(name: String, URL: URL) {
        self.URL = URL
        let name = URL.lastPathComponent
        self.name = name
        self.path = URL.path().removingPercentEncoding ?? "Unknown"
        self.cacheURL = FileManager.default.temporaryDirectory.appendingPathComponent(name)
        
        let logger = Logger(
            subsystem: Bundle.main.bundleIdentifier!,
            category: String(describing: Archive.self) + name
        )
        self.logger = logger
        self.root = ArchiveEntry(isRoot: true, forArchive: self)

        logger.trace("Initialised for \(self.URL)")
    }

    deinit {
        self.close()
    }

    func open() async {
        do {
            try FileManager.default.createDirectory(at: self.cacheURL, withIntermediateDirectories: true)
        } catch {
            logger.error("Unable to create cache directory: \(self.cacheURL)")
            self.error = "Unable to create cache directory"
            return
        }

        let libarchive = libarchive(url: self.URL)
        
        do {
            try await libarchive.readEntriesFormatFilters()
        } catch {
            self.error = error.localizedDescription
            return
        }
        let entries = await libarchive.entries
        self.entries = entries.map { ArchiveEntry($0, forArchive: self) }
        self.format = await libarchive.format
        self.filters = await libarchive.filters

        let (rootItems, remainingAll) = self.entries.filterBothwise { $0.path.countOccurrences(of: "/") == 0 }
        self.root.addChildren(rootItems)
        
        let (remainingDirs, remainingFiles) = remainingAll.filterBothwise { $0.type == .directory }
        self.root.addChildrenHierarchically(remainingDirs)
        self.root.addChildrenHierarchically(remainingFiles)
    }

    private func close() {
        logger.trace("Archive::close() on \(self.name)")
        do {
            try FileManager.default.removeItem(at: self.cacheURL)
        } catch {
            logger.error("Unable to remove cache directory at: \(self.cacheURL)")
        }
    }

    // NOTE: These write methods do not use any async, but are self-contained and can be called from a background thread
    func extractEntryToCache(_ entry: ArchiveEntry) async throws -> [URL] {
        return try await extractEntries([entry], toFolder: cacheURL)
    }

    func extractEntry(_ entry: ArchiveEntry, toFolder: URL) async throws -> [URL] {
        return try await extractEntries([entry], toFolder: toFolder)
    }

    // NOTE: This method doesn't throw because it's called from SwiftUI and it's better to handle the errors here
    func extractEntries(_ entries: Set<ArchiveEntry.ID>, toFolder: URL) async -> [URL] {
        let foundEntries = self.entries.filter { entries.contains($0.id) }
        do {
            return try await extractEntries(foundEntries, toFolder: toFolder)
        } catch {
            self.error = "Unable to extract selected items"
            return []
        }
    }

    func extractEntries(_ entries: [ArchiveEntry], toFolder: URL) async throws -> [URL] {
        var writtenURLS: [URL] = []

        logger.trace("extractEntries: extracting \(entries.count) items to: \(toFolder)")

        // Convert entries, which can be a tree, into a flat list for our libarchive walk below
        var flatEntries: [ArchiveEntry] = []
        for entry in entries {
            flatEntries += entry.flatChildren()
        }

        // Before we touch libarchive, deal with any synthetic directories first
        for (index, entry) in flatEntries.enumerated().reversed() {
            if entry.isSynthesized {
                logger.trace("Handling synthesised entry: \(entry.path)")

                // Whether we succeed or fail here, we don't need this again later
                flatEntries.remove(at: index)

                let folderURL = toFolder.appending(path: entry.pathComponents.joined(separator: "/"), directoryHint: .isDirectory)
                try FileManager.default.createDirectory(at: folderURL, withIntermediateDirectories: true)
                writtenURLS.append(folderURL)
            }
        }

        let libarchive = libarchive(url: self.URL)
        do {
            try await writtenURLS = libarchive.extractEntries(flatEntries.map { $0.path }, toFolder: toFolder)
        } catch {
            self.error = error.localizedDescription
            return writtenURLS
        }

        return writtenURLS
    }

    func processInternalDrop(providers:[NSItemProvider], atIndex:Int, treeHint:[ArchiveEntry]) {
        // Process internal drops
//        let decoder = JSONDecoder()
//        let id: UUID
//
//        let group = DispatchGroup()
//        let result =
//        provider.loadDataRepresentation(for: ArchiveEntry.draggableType) { data, error in
//            guard let data = data else { return }
//            let id = try? decoder.decode(UUID.self, from: data)
//        }
    }

    func processExternalDrop(providers:[NSItemProvider], atIndex:Int, treeHint:[ArchiveEntry]) {

    }
}
