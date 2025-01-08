//
//  libarchive.swift
//  ZipZap
//
//  Created by Chris Jones on 11/06/2024.
//

import Foundation
import SwiftUI
import ZZLog

actor libarchive {
    private var readArchive = libarchiveFD(type: .read)
    private var writeArchive = libarchiveFD(type: .write)

    private var url: URL
    private var path: String {
        get { url.path.removingPercentEncoding ?? "Unknown" }
    }

    enum DateTypes {
        case atime
        case ctime
        case mtime
        case btime
    }

    init(url: URL) {
        self.url = url
    }

    private func readDate(_ dateType: DateTypes, for entry: OpaquePointer?) -> Date {
        switch dateType {
        case .atime:
            if archive_entry_atime_is_set(entry) != 0 {
                return Date(since: archive_entry_atime(entry))
            }
        case .ctime:
            if archive_entry_ctime_is_set(entry) != 0 {
                return Date(since: archive_entry_ctime(entry))
            }
        case .mtime:
            if archive_entry_mtime_is_set(entry) != 0 {
                return Date(since: archive_entry_mtime(entry))
            }
        case .btime:
            if archive_entry_birthtime_is_set(entry) != 0 {
                return Date(since: archive_entry_birthtime(entry))
            }
        }
        return Date(since: 0)
    }

    private func readHeaders() throws -> [libarchiveHeader] {
        guard readArchive.archive != nil else {
            throw ArchiveError.ArchiveEntriesError(archive: path, error: "readHeaders() called before archive was opened")
        }

        var headers: [libarchiveHeader] = []

        var entry: OpaquePointer?
        while (archive_read_next_header(readArchive.archive, &entry) == ARCHIVE_OK) {
            let name: String
            let path: String
            let pathComponents: [String]
            let size: Int64
            let atime: Date
            let ctime: Date
            let mtime: Date
            let btime: Date
            let perms: mode_t
            let uid: String
            let gid: String
            let type: ArchiveEntryType
            let source: ArchiveEntrySource

            if let pathString = entryPath(entry) {
                path = pathString
                pathComponents = pathString.split(separator: "/").map(String.init)
                name = pathComponents.last ?? "Unknown"
            } else {
                path = "Unknown"
                name = "Unknown"
                pathComponents = []
            }

            source = ArchiveEntrySource(type: .Archive, path: path)

            if archive_entry_size_is_set(entry) != 0 {
                size = archive_entry_size(entry)
            } else {
                size = -1
            }

            atime = readDate(.atime, for: entry)
            ctime = readDate(.ctime, for: entry)
            mtime = readDate(.mtime, for: entry)
            btime = readDate(.btime, for: entry)

            perms = archive_entry_mode(entry)

            if archive_entry_uid_is_set(entry) != 0 {
                uid = "\(archive_entry_uid(entry))"
            } else {
                uid = "--"
            }
            if archive_entry_gid_is_set(entry) != 0 {
                gid = "\(archive_entry_gid(entry))"
            } else {
                gid = "--"
            }

            type = ArchiveEntryType(rawValue: archive_entry_filetype(entry))

            headers.append(libarchiveHeader(source: source, type: type, path: path, name: name, pathComponents: pathComponents, size: size, atime: atime, ctime: ctime, mtime: mtime, btime: btime, uid: uid, gid: gid, perms: perms))
        }

        return headers
    }

    private func readFormat() -> libarchiveFormat {
        return libarchiveFormat(rawValue: archive_format(readArchive.archive)) ?? .Unknown
    }

    private func readFilters() -> [libarchiveFilter] {
        var filters: [libarchiveFilter] = []

        for i in 0...archive_filter_count(readArchive.archive) {
            if let filter = libarchiveFilter(rawValue: archive_filter_code(readArchive.archive, i)) {
                filters.append(filter)
            }
        }

        return filters
    }

    private func entryPath(_ entry: OpaquePointer?) -> String? {
        var string: String? = nil

        if let cString = archive_entry_pathname(entry) {
            string = String(cString: cString)
        }

        // Lots of archives include trailing slashes on their path names, which is annoying and unnecessary.
        if string != nil && string?.last == "/" {
            string = String(string!.dropLast())
        }

        return string
    }

    func readEntriesFormatFilters() throws -> (libarchiveFormat, [libarchiveFilter], [libarchiveHeader]) {
        try readArchive.openRead(path: path)
        defer { readArchive.close() }

        let headers = try readHeaders()
        let format = readFormat()
        let filters = readFilters()

        return (format, filters, headers)
    }

    func loadArchive() async throws(ArchiveError) -> sending Archive {
        let archive = Archive(URL: self.url)
        let archiveFormat: libarchiveFormat
        let archiveFilters: [libarchiveFilter]
        let archiveEntries: [libarchiveHeader]

        await Task.unsafeProgress?.progressed()
        do {
            (archiveFormat, archiveFilters, archiveEntries) = try readEntriesFormatFilters()

            let entries = archiveEntries.map { ArchiveEntry($0) }
            let (rootItems, remainingAll) = entries.filterBothwise { $0.path.countOccurrences(of: "/") == 0 }
            let (remainingDirs, remainingFiles) = remainingAll.filterBothwise { $0.type == .directory }

            let root = ArchiveEntry(isRoot: true)
            root.addChildren(rootItems)
            root.addChildrenHierarchically(remainingDirs, for: archive)
            root.addChildrenHierarchically(remainingFiles, for: archive)

            archive.root = root
            archive.entries = entries
            archive.format = archiveFormat
            archive.filters = archiveFilters
        } catch {
            let error = ArchiveError.ArchiveOpenError(archive: self.path, error: error.localizedDescription)
            throw error
        }

        return archive
    }

    func extractEntries(_ extractableEntries: [ArchiveEntryExtractable], toFolder: URL, retainFullPath: Bool = false) async throws(ArchiveError) -> [URL] {
        var pathMap: [String:URL] = [:]
        var writtenURLs: [URL] = []
        var entryPtr: OpaquePointer?

        try readArchive.openRead(path: path)
        defer { readArchive.close() }

        let synthPaths = extractableEntries.flatMap { $0.entries.filter { $0.isSynthesized == true }}
        for synthPath in synthPaths {
            let synthURL = toFolder.appendingPathComponent(synthPath.path)
            do {
                try FileManager.default.createDirectory(at: synthURL, withIntermediateDirectories: true)
            } catch {
                throw ArchiveError.ArchiveExtractError(archive: synthPath.path, error: error.localizedDescription)
            }
            writtenURLs.append(synthURL)
        }

        for extractableEntry in extractableEntries {
            let entryBasePath = extractableEntry.basePath
            for entry in extractableEntry.entries.filter({ $0.isSynthesized == false }) {
                var outputURL: URL
                if retainFullPath {
                    outputURL = toFolder.appendingPathComponent(entry.path)
                } else {
                    outputURL = toFolder.appendingPathComponent(entry.path.deletingPrefix(entryBasePath))
                }
                pathMap[entry.path] = outputURL
            }
        }

        #ZZTrace("Extracting \(pathMap.count) entries to \(toFolder.path)")

        while (archive_read_next_header(readArchive.archive, &entryPtr) == ARCHIVE_OK) {
            if let path = entryPath(entryPtr) {
                if pathMap.keys.contains(path) {
                    guard let outputURL = pathMap[path] else { continue }
                    let entryType = ArchiveEntryType(rawValue: archive_entry_filetype(entryPtr))
                    switch entryType {
                    case .file:
                        // Ensure all intermediate directories exist, incase we're extracting multiple levels of files that may not arrive in an order that guarantees their parent folder (synthetic or otherwise) is created first
                        do {
                            try FileManager.default.createDirectory(at: outputURL.deletingLastPathComponent(), withIntermediateDirectories: true)
                        } catch {
                            throw ArchiveError.ArchiveExtractError(archive: outputURL.deletingLastPathComponent().path,
                                                                   error: error.localizedDescription)
                        }

                        // Ensure our file exists
                        let handle: FileHandle
                        do {
                            try Data().write(to: outputURL)
                            handle = try FileHandle(forWritingTo: outputURL)
                        } catch {
                            throw ArchiveError.ArchiveExtractError(archive: outputURL.path,
                                                                   error: error.localizedDescription)
                        }
                        let result = archive_read_data_into_fd(readArchive.archive, handle.fileDescriptor)
                        if result != ARCHIVE_OK {
                            let error = "Unable to write to \(outputURL.path)"
                            throw ArchiveError.ArchiveExtractError(archive: path, error: error)
                        }
                        #ZZTrace("  Wrote \(outputURL.path(percentEncoded: false))")

                        writtenURLs.append(outputURL)
                    case .directory:
                        do {
                            try FileManager.default.createDirectory(at: outputURL, withIntermediateDirectories: true)
                        } catch {
                            throw ArchiveError.ArchiveExtractError(archive: outputURL.path, error: error.localizedDescription)
                        }
                        archive_read_data_skip(readArchive.archive)
                        #ZZTrace("  Created \(outputURL.path(percentEncoded: false))")

                        writtenURLs.append(outputURL)
                    case .symlink:
                        let linkDest = String(cString: archive_entry_symlink(entryPtr))

                        do {
                            try FileManager.default.createSymbolicLink(atPath: outputURL.path, withDestinationPath: linkDest, overwrite: true)
                        } catch {
                            throw ArchiveError.ArchiveExtractError(archive: outputURL.path, error: error.localizedDescription)
                        }
                        #ZZTrace("  Linked \(outputURL.path) to \(linkDest)")
                    default:
                        #ZZWarn("Skipping archive entry \(path) of type \(entryType.rawValue), it is an unsupported type")
                    }

                    // Set some metadata on the filesystem object we just wrote
                    let btime = readDate(.btime, for: entryPtr)
                    let mtime = readDate(.mtime, for: entryPtr)

                    do {
                        var attributes: [FileAttributeKey : Any] = [:]

                        if (btime != Date(since: 0)) {
                            attributes[.creationDate] = btime
                        }
                        if (mtime != Date(since: 0)) {
                            attributes[.modificationDate] = mtime
                        }

                        if attributes.count > 0 {
                            try FileManager.default.setAttributes(attributes, ofItemAtPath: outputURL.path)
                        }
                    } catch {
                        #ZZWarn("Unable to read/set file attributes for \(outputURL.path)")
                    }

                    await Task.unsafeProgress?.progressed()
                }
            }
        }

        return writtenURLs
    }

//    func createArchive(to: URL, format: libarchiveFormat, filters: [libarchiveFilter], entries: [libarchiveHeader]) throws {
//        try saveArchive(from: nil, to: to, format: format, filters: filters, entries: entries)
//    }

    private func writeArchiveEntryHeader(to: libarchiveFD, headers: libarchiveHeader) {
        let writeEntry = archive_entry_new()

        let data = headers.path.data(using: .utf8)!
        archive_entry_set_pathname(writeEntry, data.bytes)

        if headers.size != -1 {
            archive_entry_set_size(writeEntry, headers.size)
        }

        archive_entry_set_atime(writeEntry, Int(headers.atime.timeIntervalSince1970), 0)
        archive_entry_set_birthtime(writeEntry, Int(headers.btime.timeIntervalSince1970), 0)
        archive_entry_set_ctime(writeEntry, Int(headers.ctime.timeIntervalSince1970), 0)
        archive_entry_set_mtime(writeEntry, Int(headers.mtime.timeIntervalSince1970), 0)

        if headers.uid != "--" {
            archive_entry_set_uid(writeEntry, Int64(headers.uid) ?? 0)
        }
        if headers.gid != "--" {
            archive_entry_set_gid(writeEntry, Int64(headers.gid) ?? 0)
        }

        archive_entry_set_mode(writeEntry, headers.perms)

        archive_write_header(to.archive, writeEntry)
    }

    func writeArchive(headerMap: [String:ArchiveEntryFlat], to: URL, format: libarchiveFormat, filters: [libarchiveFilter]) async throws {
        var headerMap = headerMap
        var result: Int32 = ARCHIVE_OK

        await Task.unsafeProgress?.progressed()

        try readArchive.openRead(path: path)
        defer { readArchive.close() }
        
        try writeArchive.openWrite(at: to, format: format, filters: filters)
        defer { writeArchive.close() }

        var readEntry: OpaquePointer?
        let rbuf: UnsafeMutableRawPointer = UnsafeMutableRawPointer.allocate(byteCount: 524288, alignment: MemoryLayout<UInt8>.size)
        defer { rbuf.deallocate() }
        var rsize: size_t = size_t()
        var wsize: size_t = size_t()

        // First, examine the existing archive to find entries we need to copy over
        while (archive_read_next_header(readArchive.archive, &readEntry) == ARCHIVE_OK && result != ARCHIVE_EOF) {
            guard let readEntryPath = entryPath(readEntry) else { continue }
            
            // Find every entry in the tree that started out as this path, and in the archive
            // NOTE: We're not expecting to find multiple values here, but in the future we might want to offer the ability to duplicate a file within an archive
            for mapEntryKey in headerMap.keys.filter({ headerMap[$0]?.header.source.path == readEntryPath && headerMap[$0]?.header.source.type == .Archive }) {
                // Read from archive and write to new archive
                writeArchiveEntryHeader(to: writeArchive, headers: headerMap[mapEntryKey]!.header)

                while (true) {
                    rsize = archive_read_data(readArchive.archive, rbuf, 524288)
                    if (rsize <= 0) { break }

                    wsize = archive_write_data(writeArchive.archive, rbuf, rsize)
                    if (wsize < 0) {
                        throw ArchiveError.ArchiveWriteError(archive: to.path, error: "Failed to write data: \(String(describing: archive_error_string(writeArchive.archive))).")
                    }

                    if (rsize != wsize) {
                        // FIXME: Figure out if this is likely to happen and what we should do
                        print("HELP! rsize: \(rsize), wsize: \(wsize)")
                    }
                }

                result = archive_write_finish_entry(writeArchive.archive)
                if (result != ARCHIVE_OK) {
                    let error = String(cString: archive_error_string(writeArchive.archive))
                    throw ArchiveError.ArchiveWriteError(archive: to.path, error: error)
                }

                // Remove the headerMap value now we've processed it
                headerMap.removeValue(forKey: mapEntryKey)
            }
        }

        // Second, process any filesystem-sourced entries that have been added to the archive
        for filePath in headerMap.keys.filter({ headerMap[$0]?.header.source.type == .Filesystem }) {
            writeArchiveEntryHeader(to: writeArchive, headers: headerMap[filePath]!.header)
            
            // FIXME: Open the filesystem file here
            while (true) {
                // FIXME: Read the filesystem file in chunks here and archive_write_data() them
            }
            
            result = archive_write_finish_entry(writeArchive.archive)
            if (result != ARCHIVE_OK) {
                let error = String(cString: archive_error_string(writeArchive.archive))
                throw ArchiveError.ArchiveWriteError(archive: to.path, error: error)
            }
            
            headerMap.removeValue(forKey: filePath)
        }
        // FIXME: Deal with: do we have any headerMap entries left?
    }
}
