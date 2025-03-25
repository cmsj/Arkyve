//
//  libarchive.swift
//  ZipZap
//
//  Created by Chris Jones on 11/06/2024.
//

import Foundation
import SwiftUI
import ZZLog

/// Wrapper for all libarchive activities
actor libarchiveWrapper {
    private var readArchiveFD = libarchiveFD(type: .read)

    private var url: URL
    private var path: String {
        url.path.removingPercentEncoding ?? "Unknown"
    }

    // MARK: Internal datatypes
    enum DateTypes {
        case atime
        case ctime
        case mtime
        case btime
    }

    // MARK: Initialisers
    init(url: URL) {
        self.url = url
    }

    // MARK: Helper methods
    /// Convert a libarchive entry's date field into a Swift Date object
    /// - Parameters:
    ///   - dateType: Which type of date to read
    ///   - entry: A pointer to the libarchive entry
    /// - Returns: A Swift Date object. If the date could not be read from the archive, the epoch is returned
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

    /// Read the filesystem path of a libarchive entry, if it has one
    /// - Parameter entry: A pointer to the libarchive entry
    /// - Returns: An optional string containing the filesystem path
    private func entryPath(_ entry: OpaquePointer?) -> String? {
        var string: String? = nil

        if let cString = archive_entry_pathname(entry) {
            string = String(cString: cString)
        }

        // Lots of archives include trailing slashes on their path names, which is annoying and unnecessary.
        if string?.last == "/" {
            string = String(string!.dropLast())
        }

        return string
    }

    private func readHeaders() throws -> [libarchiveHeader] {
        guard readArchiveFD.archive != nil else {
            throw ArchiveError.ArchiveEntriesError(
                archive: path, error: "readHeaders() called before archive was opened")
        }

        var headers: [libarchiveHeader] = []

        var entry: OpaquePointer?
        readLoop: while true {
            let result = archive_read_next_header(readArchiveFD.archive, &entry)
            switch result {
            case ARCHIVE_OK:
                break
            case ARCHIVE_FATAL:
                throw ArchiveError.ArchiveOpenError(
                    archive: "", error: String(cString: archive_error_string(readArchiveFD.archive))
                )
            case ARCHIVE_EOF:
                #ZZTrace("Reached end of archive")
                break readLoop
            default:
                #ZZError("Unknown result \(result)")
                break readLoop
            }

            let name: String
            let path: String
            let pathComponents: [String]
            let size: Int64
            let atime: Date
            let ctime: Date
            let mtime: Date
            let btime: Date
            let perms: mode_t
            let uid: Int64?
            let gid: Int64?
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
                uid = archive_entry_uid(entry)
            } else {
                uid = nil
            }

            if archive_entry_gid_is_set(entry) != 0 {
                gid = archive_entry_gid(entry)
            } else {
                gid = nil
            }

            type = ArchiveEntryType(rawValue: archive_entry_filetype(entry))

            headers.append(
                libarchiveHeader(
                    source: source, type: type, path: path, name: name,
                    pathComponents: pathComponents, size: size, atime: atime, ctime: ctime,
                    mtime: mtime, btime: btime, uid: uid, gid: gid, perms: perms))
        }

        return headers
    }

    private func readFormat() -> libarchiveFormat {
        return libarchiveFormat(rawValue: archive_format(readArchiveFD.archive)) ?? .Unknown
    }

    private func readFilters() -> [libarchiveFilter] {
        var filters: [libarchiveFilter] = []

        for i in 0...archive_filter_count(readArchiveFD.archive) {
            if let filter = libarchiveFilter(
                rawValue: archive_filter_code(readArchiveFD.archive, i))
            {
                filters.append(filter)
            }
        }

        return filters
    }

    func readEntriesFormatFilters() throws -> (
        libarchiveFormat, [libarchiveFilter], [libarchiveHeader]
    ) {
        try readArchiveFD.openRead(path: path)
        defer { readArchiveFD.close() }

        let headers = try readHeaders()
        let format = readFormat()
        let filters = readFilters()

        return (format, filters, headers)
    }

    private func writeArchiveEntryHeader(to: libarchiveFD, headers: libarchiveHeader) throws {
        let writeEntry = archive_entry_new()

        guard let data = headers.path.data(using: .utf8) else {
            throw ArchiveError.ArchiveWriteError(
                archive: nil, error: "Unable to convert path to Data: \(headers.path)")
        }
        archive_entry_set_pathname(writeEntry, data.bytes)

        if headers.size != -1 {
            archive_entry_set_size(writeEntry, headers.size)
        }

        archive_entry_set_atime(writeEntry, Int(headers.atime.timeIntervalSince1970), 0)
        archive_entry_set_birthtime(writeEntry, Int(headers.btime.timeIntervalSince1970), 0)
        archive_entry_set_ctime(writeEntry, Int(headers.ctime.timeIntervalSince1970), 0)
        archive_entry_set_mtime(writeEntry, Int(headers.mtime.timeIntervalSince1970), 0)

        if let uid = headers.uid {
            archive_entry_set_uid(writeEntry, uid)
        }
        if let gid = headers.gid {
            archive_entry_set_gid(writeEntry, gid)
        }

        archive_entry_set_mode(writeEntry, headers.perms)

        archive_write_header(to.archive, writeEntry)
    }

    public func loadArchive() async throws(ArchiveError) -> sending Archive {
        #ZZTrace("loadArchive() for \(path)")
        let archive = Archive(URL: self.url)
        let archiveFormat: libarchiveFormat
        let archiveFilters: [libarchiveFilter]
        let archiveEntries: [libarchiveHeader]

        await Task.unsafeProgress?.progressed()

        do {
            (archiveFormat, archiveFilters, archiveEntries) = try readEntriesFormatFilters()

            let entries = archiveEntries.map { ArchiveEntry($0) }
            #ZZTrace("loadArchive() found \(entries.count) entries")
            let (rootItems, remainingAll) = entries.filterBothwise {
                $0.path.countOccurrences(of: "/") == 0
            }
            let (remainingDirs, remainingFiles) = remainingAll.filterBothwise {
                $0.type == .directory
            }
            let root = ArchiveEntry(isRoot: true)

            var syntheticEntries: [ArchiveEntry] = []
//            try root.addRootItems(rootItems)
            try root.addChildrenHierarchically(rootItems)
            syntheticEntries += try root.addChildrenHierarchically(remainingDirs)
            syntheticEntries += try root.addChildrenHierarchically(remainingFiles)

            let combinedEntries = entries + syntheticEntries
            archive.populate(
                root: root, entries: combinedEntries, format: archiveFormat, filters: archiveFilters
            )
        } catch {
            let error = ArchiveError.ArchiveOpenError(
                archive: self.path, error: error.localizedDescription)
            throw error
        }

        #ZZTrace("Loaded archive with format \(archiveFormat) and filters \(archiveFilters)")
        return archive
    }

    public func extractEntries(
        _ extractableEntries: [ArchiveEntryExtractable], toFolder: URL, retainFullPath: Bool = false
    ) async throws(ArchiveError) -> [URL] {
        var pathMap: [String: URL] = [:]
        var writtenURLs: [URL] = []
        var entryPtr: OpaquePointer?

        try readArchiveFD.openRead(path: path)
        defer { readArchiveFD.close() }

        let synthPaths = extractableEntries.flatMap {
            $0.entries.filter { $0.isSynthesized == true }
        }
        for synthPath in synthPaths {
            let synthURL = toFolder.appendingPathComponent(synthPath.path)
            do {
                try FileManager.default.createDirectory(
                    at: synthURL, withIntermediateDirectories: true)
            } catch {
                throw ArchiveError.ArchiveExtractError(
                    archive: synthPath.path, error: error.localizedDescription)
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
                    outputURL = toFolder.appendingPathComponent(
                        entry.path.deletingPrefix(entryBasePath))
                }
                pathMap[entry.path] = outputURL
            }
        }

        #ZZTrace("Extracting \(pathMap.count) entries to \(toFolder.path)")

        while archive_read_next_header(readArchiveFD.archive, &entryPtr) == ARCHIVE_OK {
            if let path = entryPath(entryPtr) {
                if pathMap.keys.contains(path) {
                    guard let outputURL = pathMap[path] else { continue }
                    let entryType = ArchiveEntryType(rawValue: archive_entry_filetype(entryPtr))
                    switch entryType {
                    case .file:
                        // Ensure all intermediate directories exist, incase we're extracting multiple levels of files that may not arrive in an order that guarantees their parent folder (synthetic or otherwise) is created first
                        do {
                            try FileManager.default.createDirectory(
                                at: outputURL.deletingLastPathComponent(),
                                withIntermediateDirectories: true)
                        } catch {
                            throw ArchiveError.ArchiveExtractError(
                                archive: outputURL.deletingLastPathComponent().path,
                                error: error.localizedDescription)
                        }

                        // Ensure our file exists
                        let handle: FileHandle
                        do {
                            try Data().write(to: outputURL)
                            handle = try FileHandle(forWritingTo: outputURL)
                        } catch {
                            throw ArchiveError.ArchiveExtractError(
                                archive: outputURL.path,
                                error: error.localizedDescription)
                        }
                        let result = archive_read_data_into_fd(
                            readArchiveFD.archive, handle.fileDescriptor)
                        if result != ARCHIVE_OK {
                            let error = "Unable to write to \(outputURL.path)"
                            throw ArchiveError.ArchiveExtractError(archive: path, error: error)
                        }
                        #ZZTrace("  Wrote \(outputURL.path(percentEncoded: false))")

                        writtenURLs.append(outputURL)
                    case .directory:
                        do {
                            try FileManager.default.createDirectory(
                                at: outputURL, withIntermediateDirectories: true)
                        } catch {
                            throw ArchiveError.ArchiveExtractError(
                                archive: outputURL.path, error: error.localizedDescription)
                        }
                        archive_read_data_skip(readArchiveFD.archive)
                        #ZZTrace("  Created \(outputURL.path(percentEncoded: false))")

                        writtenURLs.append(outputURL)
                    case .symlink:
                        let linkDest = String(cString: archive_entry_symlink(entryPtr))

                        do {
                            try FileManager.default.createSymbolicLink(
                                atPath: outputURL.path, withDestinationPath: linkDest,
                                overwrite: true)
                        } catch {
                            throw ArchiveError.ArchiveExtractError(
                                archive: outputURL.path, error: error.localizedDescription)
                        }
                        #ZZTrace("  Linked \(outputURL.path) to \(linkDest)")
                    default:
                        #ZZWarn(
                            "Skipping archive entry \(path) of type \(entryType.rawValue), it is an unsupported type"
                        )
                    }

                    // Set some metadata on the filesystem object we just wrote
                    let btime = readDate(.btime, for: entryPtr)
                    let mtime = readDate(.mtime, for: entryPtr)

                    do {
                        var attributes: [FileAttributeKey: Any] = [:]

                        if btime != Date(since: 0) {
                            attributes[.creationDate] = btime
                        }
                        if mtime != Date(since: 0) {
                            attributes[.modificationDate] = mtime
                        }

                        if attributes.count > 0 {
                            try FileManager.default.setAttributes(
                                attributes, ofItemAtPath: outputURL.path)
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

    /// Write the archive to a URL
    /// - Parameters:
    ///   - headerMap: A dictionary containing path to ArchiveEntryFlat mappings. This determines the entries that will be written to the new archive
    ///   - to: A URL describing the filesystem location to write the archive to
    ///   - format: A libarchiveFormat describing the type of archive to write
    ///   - filters: An array of libarchiveFilter, describing which filters to apply to the archive
    public func writeArchive(
        headerMap: [String: ArchiveEntryFlat], to: URL, format: libarchiveFormat,
        filters: [libarchiveFilter]
    ) async throws {
        var headerMap = headerMap
        var result: Int32 = ARCHIVE_OK

        try readArchiveFD.openRead(path: path)
        defer { readArchiveFD.close() }

        var writeArchiveFD = libarchiveFD(type: .write)
        try writeArchiveFD.openWrite(at: to, format: format, filters: filters)
        defer { writeArchiveFD.close() }

        var readEntry: OpaquePointer?
        let rbuf: UnsafeMutableRawPointer = UnsafeMutableRawPointer.allocate(
            byteCount: 524288, alignment: MemoryLayout<UInt8>.size)
        defer { rbuf.deallocate() }
        var rsize: size_t = size_t()
        var wsize: size_t = size_t()

        // First, examine the existing archive to find entries we need to copy over
        while archive_read_next_header(readArchiveFD.archive, &readEntry) == ARCHIVE_OK && result != ARCHIVE_EOF
        {
            guard let readEntryPath = entryPath(readEntry) else { continue }

            // Find every entry in the tree that started out as this path, and in the archive
            // NOTE: We're not expecting to find multiple values here, but in the future we might want to offer the ability to duplicate a file within an archive
            let mapEntryKeys = headerMap.keys.filter {
                headerMap[$0]?.header.source.path == readEntryPath && headerMap[$0]?.header.source.type == .Archive
            }

            guard !mapEntryKeys.isEmpty else {
                archive_read_data_skip(readArchiveFD.archive)
                continue
            }

            for mapEntryKey in mapEntryKeys {
                guard let header = headerMap[mapEntryKey]?.header else { continue }

                // Read from archive and write to new archive
                try writeArchiveEntryHeader(to: writeArchiveFD, headers: header)

                while true {
                    rsize = archive_read_data(readArchiveFD.archive, rbuf, 524288)
                    if rsize <= 0 { break }

                    wsize = archive_write_data(writeArchiveFD.archive, rbuf, rsize)
                    if wsize < 0 {
                        throw ArchiveError.ArchiveWriteError(
                            archive: to.path,
                            error:
                                "Failed to write data: \(String(describing: archive_error_string(writeArchiveFD.archive)))."
                        )
                    }

                    if rsize != wsize {
                        throw ArchiveError.ArchiveWriteError(
                            archive: to.path,
                            error:
                                "Data size mismatch during write: read \(rsize) bytes but wrote \(wsize) bytes"
                        )
                    }
                }

                result = archive_write_finish_entry(writeArchiveFD.archive)
                if result != ARCHIVE_OK {
                    let error = String(cString: archive_error_string(writeArchiveFD.archive))
                    throw ArchiveError.ArchiveWriteError(archive: to.path, error: error)
                }

                await Task.unsafeProgress?.progressed()

                // Remove the headerMap value now we've processed it
                headerMap.removeValue(forKey: mapEntryKey)
            }
        }

        // Second, process any filesystem-sourced entries that have been added to the archive
        for filePath in headerMap.keys.filter({ headerMap[$0]?.header.source.type == .Filesystem })
        {
            try writeArchiveEntryHeader(to: writeArchiveFD, headers: headerMap[filePath]!.header)

            let fileURL = URL(fileURLWithPath: filePath)
            guard let fileHandle = try? FileHandle(forReadingFrom: fileURL) else {
                throw ArchiveError.ArchiveWriteError(
                    archive: to.path, error: "Failed to open file for reading: \(filePath)")
            }
            defer { try? fileHandle.close() }

            while true {
                let data = try fileHandle.read(upToCount: 524288)
                guard let data = data, !data.isEmpty else { break }

                try? data.withUnsafeBytes { ptr in
                    let wsize = archive_write_data(
                        writeArchiveFD.archive, ptr.baseAddress, data.count)
                    if wsize < 0 {
                        throw ArchiveError.ArchiveWriteError(
                            archive: to.path,
                            error:
                                "Failed to write data: \(String(describing: archive_error_string(writeArchiveFD.archive)))"
                        )
                    }
                    if wsize != data.count {
                        throw ArchiveError.ArchiveWriteError(
                            archive: to.path,
                            error:
                                "Data size mismatch during write: expected \(data.count) bytes but wrote \(wsize) bytes"
                        )
                    }
                }
            }

            result = archive_write_finish_entry(writeArchiveFD.archive)
            if result != ARCHIVE_OK {
                let error = String(cString: archive_error_string(writeArchiveFD.archive))
                throw ArchiveError.ArchiveWriteError(archive: to.path, error: error)
            }

            await Task.unsafeProgress?.progressed()

            headerMap.removeValue(forKey: filePath)
        }
        // FIXME: Deal with: do we have any headerMap entries left?
        if !headerMap.isEmpty {
            #ZZWarn(
                "Some entries were not processed during archive write: \(headerMap.keys.joined(separator: ", "))"
            )
        }

        writeArchiveFD.close()

        if let writeCacheURL = writeArchiveFD.writeCacheURL {
            #ZZTrace("Moving archive cache to final destination: \(writeCacheURL) -> \(to)")
            do {
                _ = try FileManager.default.replaceItemAt(
                    to, withItemAt: writeCacheURL, options: [.usingNewMetadataOnly])
            } catch {
                try FileManager.default.moveItem(at: writeCacheURL, to: to)
            }
        }
    }
}
