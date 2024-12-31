//
//  libarchive.swift
//  ZipZap
//
//  Created by Chris Jones on 11/06/2024.
//

import Foundation
import SwiftUI
import ZZLog

enum DateTypes {
    case atime
    case ctime
    case mtime
    case btime
}

extension FileManager {
    func createSymbolicLink(atPath path: String, withDestinationPath destPath: String, overwrite: Bool) throws {
        if !overwrite {
            // Easy path
            try self.createSymbolicLink(atPath: path, withDestinationPath: destPath)
        }

        if symlink(destPath, path) == -1 {
            if errno == EEXIST {
                try self.removeItem(atPath: path)
                try self.createSymbolicLink(atPath: path, withDestinationPath: destPath)
            }
        }
    }
}

actor libarchive {
    private var fd: Int32 = -1
    private var archive: OpaquePointer? = nil
    private var writeArchive: OpaquePointer? = nil

    private var url: URL
    private var path: String {
        get { url.path.removingPercentEncoding ?? "Unknown" }
    }

    init(url: URL) {
        self.url = url
    }

    private func open() throws(ArchiveError) {
        if fd >= 0 || archive != nil {
            close()
        }

        // Prepare libarchive's data structure
        archive = archive_read_new()
        if archive == nil {
            throw ArchiveError.ArchiveOpenError(archive: path, error: "Memory allocation failed")
        }
        archive_read_support_filter_all(archive)
        archive_read_support_format_all(archive)

        fd = Darwin.open(path, O_RDONLY)
        if fd < 0 {
            close()
            throw ArchiveError.ArchiveOpenError(archive: path, error: "open() failed: \(errno)")
        }

        let ptr = archive_read_open_fd(archive, fd, 10240)
        if ptr != ARCHIVE_OK {
            let errStr = String(cString: archive_error_string(archive))
            close()
            throw ArchiveError.ArchiveOpenError(archive: path, error:errStr)
        }
    }

    private func close() {
        if archive != nil {
            archive_read_free(archive)
            archive = nil
        }
        if fd >= 0 {
            Darwin.close(fd)
        }
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
        guard archive != nil else {
            throw ArchiveError.ArchiveEntriesError(archive: path, error: "readHeaders() called before archive was opened")
        }

        var headers: [libarchiveHeader] = []

        var entry: OpaquePointer?
        while (archive_read_next_header(archive, &entry) == ARCHIVE_OK) {
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
        return libarchiveFormat(rawValue: archive_format(archive)) ?? .Unknown
    }

    private func readFilters() -> [libarchiveFilter] {
        var filters: [libarchiveFilter] = []

        for i in 0...archive_filter_count(archive) {
            if let filter = libarchiveFilter(rawValue: archive_filter_code(archive, i)) {
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
        try open()
        defer { close() }

        let headers = try readHeaders()
        let format = readFormat()
        let filters = readFilters()

        return (format, filters, headers)
    }

    func readArchive() throws(ArchiveError) -> sending Archive {
        let archive = Archive(URL: self.url)
        let archiveFormat: libarchiveFormat
        let archiveFilters: [libarchiveFilter]
        let archiveEntries: [libarchiveHeader]

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
            throw ArchiveError.ArchiveOpenError(archive: self.path, error: error.localizedDescription)
        }

        return archive
    }

    func extractEntries(_ extractableEntries: [ArchiveEntryExtractable], toFolder: URL, retainFullPath: Bool = false) throws(ArchiveError) -> [URL] {
        var pathMap: [String:URL] = [:]
        var writtenURLs: [URL] = []
        var entryPtr: OpaquePointer?

        try open()
        defer { close() }

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

        while (archive_read_next_header(archive, &entryPtr) == ARCHIVE_OK) {
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
                        let result = archive_read_data_into_fd(archive, handle.fileDescriptor)
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
                        archive_read_data_skip(archive)
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
                }
            }
        }

        return writtenURLs
    }

//    func createArchive(to: URL, format: libarchiveFormat, filters: [libarchiveFilter], entries: [libarchiveHeader]) throws {
//        try saveArchive(from: nil, to: to, format: format, filters: filters, entries: entries)
//    }

    func writeArchive(headerMap: [String:ArchiveEntryFlat], to: URL, format: libarchiveFormat, filters: [libarchiveFilter]) throws {
        var headerMap = headerMap
        var readResult: Int32
        var writeResult: Int32

        try open()
        defer { close() }

        writeArchive = archive_write_new()
        if (writeArchive == nil) {
            throw ArchiveError.ArchiveWriteError(archive: to.path, error: "Unable to allocate memory")
        }

        writeResult = archive_write_set_format(writeArchive, format.rawValue)
        if (writeResult != ARCHIVE_OK) {
            throw ArchiveError.ArchiveWriteError(archive: to.path, error: "Unable to set format: \(String(describing: archive_error_string(writeArchive)))")
        }

        for filter in filters {
            writeResult = archive_write_add_filter(writeArchive, filter.rawValue)
            if (writeResult != ARCHIVE_OK) {
                throw ArchiveError.ArchiveWriteError(archive: to.path, error: "Unable tp add filter: \(String(describing: archive_error_string(writeArchive)))")
            }
        }

        // Figure out cache filename
        let cachePath = SettingsManager.shared.writeCacheURL.appendingPathComponent(to.lastPathComponent).path

        #ZZTrace("Writing archive to cache \(cachePath)")

        writeResult = archive_write_open_filename(writeArchive, cachePath)
        if (writeResult != ARCHIVE_OK) {
            throw ArchiveError.ArchiveWriteError(archive: to.path, error: "Unable to open output archive: \(String(describing: archive_error_string(writeArchive)))")
        }

        var readEntry: OpaquePointer?
        let rbuf: UnsafeMutableRawPointer = UnsafeMutableRawPointer.allocate(byteCount: 524288, alignment: MemoryLayout<UInt8>.size)
        defer { rbuf.deallocate() }
        var rsize: size_t = size_t()
        var wsize: size_t = size_t()

        while (archive_read_next_header(archive, &readEntry) == ARCHIVE_OK && writeResult != ARCHIVE_EOF) {
            guard let path = entryPath(readEntry) else { continue }
            if headerMap[path] != nil && headerMap[path]?.header.source.type == .Archive {
                // Read from archive and write to new archive
                let writeEntry = archive_entry_new()
                let readHeader = headerMap[path]!.header

                let data = readHeader.path.data(using: .utf8)!
                archive_entry_set_pathname(writeEntry, data.bytes)

                if readHeader.size != -1 {
                    archive_entry_set_size(writeEntry, readHeader.size)
                }

                archive_entry_set_atime(writeEntry, Int(readHeader.atime.timeIntervalSince1970), 0)
                archive_entry_set_birthtime(writeEntry, Int(readHeader.btime.timeIntervalSince1970), 0)
                archive_entry_set_ctime(writeEntry, Int(readHeader.ctime.timeIntervalSince1970), 0)
                archive_entry_set_mtime(writeEntry, Int(readHeader.mtime.timeIntervalSince1970), 0)

                if readHeader.uid != "--" {
                    archive_entry_set_uid(writeEntry, Int64(readHeader.uid) ?? 0)
                }
                if readHeader.gid != "--" {
                    archive_entry_set_gid(writeEntry, Int64(readHeader.gid) ?? 0)
                }

                archive_entry_set_mode(writeEntry, readHeader.perms)

                archive_write_header(writeArchive, writeEntry)

                while (true) {
                    rsize = archive_read_data(archive, rbuf, 524288)
                    if (rsize <= 0) { break }

                    wsize = archive_write_data(writeArchive, rbuf, rsize)
                    if (wsize < 0) {
                        throw ArchiveError.ArchiveWriteError(archive: to.path, error: "Failed to write data: \(String(describing: archive_error_string(writeArchive))).")
                    }

                    if (rsize != wsize) {
                        // FIXME: Figure out if this is likely to happen and what we should do
                        print("HELP! rsize: \(rsize), wsize: \(wsize)")
                    }
                }

                writeResult = archive_write_finish_entry(writeArchive)
                if (writeResult != ARCHIVE_OK) {
                    let error = String(cString: archive_error_string(writeArchive))
                    throw ArchiveError.ArchiveWriteError(archive: cachePath, error: error)
                }
            }
        }

        archive_write_close(writeArchive)
        archive_write_free(writeArchive)
    }
}
