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

    private var url: URL
    private var path: String
    private(set) var headers: [libarchiveHeader] = []
    private(set) var format: libarchiveFormat = .Unknown
    private(set) var filters: [libarchiveFilter] = []
    
    init(url: URL) {
        self.url = url
        self.path = url.path().removingPercentEncoding ?? "Unknown"
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

    private func readHeaders() throws {
        guard archive != nil else {
            throw ArchiveError.ArchiveEntriesError(archive: path, error: "readHeaders() called before archive was opened")
        }

        headers = []

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
            let perms: String
            let uid: String
            let gid: String
            let type: ArchiveEntryType

            if let pathString = entryPath(entry) {
                path = pathString
                pathComponents = pathString.split(separator: "/").map(String.init)
                name = pathComponents.last ?? "Unknown"
            } else {
                path = "Unknown"
                name = "Unknown"
                pathComponents = []
            }

            if archive_entry_size_is_set(entry) != 0 {
                size = archive_entry_size(entry)
            } else {
                size = -1
            }

            atime = readDate(.atime, for: entry)
            ctime = readDate(.ctime, for: entry)
            mtime = readDate(.mtime, for: entry)
            btime = readDate(.btime, for: entry)

            if let modeCstring = archive_entry_strmode(entry) {
                perms = String(cString: modeCstring)
            } else {
                perms = "--"
            }

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

            headers.append(libarchiveHeader(type: type, path: path, name: name, pathComponents: pathComponents, size: size, atime: atime, ctime: ctime, mtime: mtime, btime: btime, uid: uid, gid: gid, perms: perms))
        }
    }

    private func readFormat() {
        format = libarchiveFormat(rawValue: archive_format(archive)) ?? .Unknown
    }

    private func readFilters() {
        for i in 0...archive_filter_count(archive) {
            if let filter = libarchiveFilter(rawValue: archive_filter_code(archive, i)) {
                filters.append(filter)
            }
        }
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

        try readHeaders()
        readFormat()
        readFilters()

        return (self.format, self.filters, self.headers)
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

            let root = ArchiveEntry(isRoot: true)!
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

        #ZZTrace("Extracting \(extractableEntries.count) entries to \(toFolder.path)")

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
                            throw ArchiveError.ArchiveExtractError(archive: outputURL.deletingLastPathComponent().path, error: error.localizedDescription)
                        }

                        // Ensure our file exists
                        let handle: FileHandle
                        do {
                            try Data().write(to: outputURL)
                            handle = try FileHandle(forWritingTo: outputURL)
                        } catch {
                            throw ArchiveError.ArchiveExtractError(archive: outputURL.path, error: error.localizedDescription)
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
//
//    func saveArchive(from: URL?, to: URL, format: libarchiveFormat, filters: [libarchiveFilter], entries: [libarchiveHeader]) throws {
//        let writeArchive = archive_write_new()
//        archive_write_set_format(writeArchive, format.rawValue)
//        for filter in filters {
//            archive_write_add_filter(writeArchive, filter.rawValue)
//        }
//        
//    }
}
