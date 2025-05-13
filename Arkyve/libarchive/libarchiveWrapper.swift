//
//  libarchive.swift
//  Arkyve
//
//  Created by Chris Jones on 11/06/2024.
//

import Foundation
import SwiftUI

/// Wrapper for all libarchive activities
actor libarchiveWrapper {
    private var readArchiveFD = libarchiveFD(type: .read)

    private var url: URL
    private var path: String {
        url.path.removingPercentEncoding ?? "Unknown"
    }

#if DEBUG
    // periphery:ignore
    func testURL() -> URL {
        return url
    }

    // periphery:ignore
    func testPath() -> String {
        return path
    }
#endif

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

    private func readHeaders() async throws(ArkyveError) -> [libarchiveHeader] {
        guard readArchiveFD.archive != nil else {
            throw .init(.entries, msg: "Internal error: archive does not exist")
        }

        var headers: [libarchiveHeader] = []

        var entry: OpaquePointer?
        readLoop: while true {
            let result = archive_read_next_header(readArchiveFD.archive, &entry)
            switch result {
            case ARCHIVE_OK:
                break
            case ARCHIVE_FATAL:
                throw ArkyveError(.openArchive, msg: String(cString: archive_error_string(readArchiveFD.archive))
                )
            case ARCHIVE_EOF:
                AKTrace("Reached end of archive")
                break readLoop
            default:
                AKError("readHeaders() Unknown result \(result)")
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

            var symlinkTarget: String? = nil
            var rdev: dev_t? = nil

            switch type {
            case .directory, .file:
                // No further info required
                break
            case .symlink:
                symlinkTarget = String(cString: archive_entry_symlink_utf8(entry))
            case .blockdev, .chardev:
                if archive_entry_rdev_is_set(entry) != 0 {
                    rdev = archive_entry_rdev(entry)
                } else {
                    let major = archive_entry_rdevmajor(entry)
                    let minor = archive_entry_rdevminor(entry)
                    rdev = minor | major << 24
                }
            case .socket, .fifo, .root, .unknown:
                AKWarning("Discarding header for \(path) because it is not a supported type: \(type.userString)")
            }

            headers.append(libarchiveHeader(
                source: source, type: type, path: path, name: name,
                pathComponents: pathComponents, size: size, atime: atime, ctime: ctime,
                mtime: mtime, btime: btime, uid: uid, gid: gid, perms: perms, symlinkTarget: symlinkTarget, rdev: rdev))

            if Task.isCancelled {
                throw .init(.cancelled, msg: "")
            }
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

        if filters.count == 0 {
            filters.append(.None)
        }
        return filters
    }

    func readEntriesFormatFilters() async throws(ArkyveError) -> (libarchiveFormat,
                                               [libarchiveFilter],
                                               [libarchiveHeader]) {
        try readArchiveFD.openRead(path: path)
        defer { readArchiveFD.close() }

        let headers = try await readHeaders()
        let format = readFormat()
        let filters = readFilters()

        return (format, filters, headers)
    }

    private func writeArchiveEntryHeader(to: libarchiveFD, headers: libarchiveHeader) throws(ArkyveError) -> OpaquePointer {
        guard let writeEntry = archive_entry_new() else {
            throw .init(.writeArchive, msg: String(localized: "Unable to create new entry"))
        }

        archive_entry_set_pathname(writeEntry, headers.path.cString(using: .utf8))

        if headers.size != -1 {
            archive_entry_set_size(writeEntry, headers.size)
        }

        archive_entry_set_atime(writeEntry,     Int(headers.atime.timeIntervalSince1970), 0)
        archive_entry_set_birthtime(writeEntry, Int(headers.btime.timeIntervalSince1970), 0)
        archive_entry_set_ctime(writeEntry,     Int(headers.ctime.timeIntervalSince1970), 0)
        archive_entry_set_mtime(writeEntry,     Int(headers.mtime.timeIntervalSince1970), 0)

        if let uid = headers.uid {
            archive_entry_set_uid(writeEntry, uid)
        }
        if let gid = headers.gid {
            archive_entry_set_gid(writeEntry, gid)
        }

        archive_entry_set_mode(writeEntry, headers.perms)

        switch headers.type {
        case .symlink:
            if let symlinkTarget = headers.symlinkTarget {
                archive_entry_set_symlink(writeEntry, symlinkTarget.cString(using: .utf8))
            }
        case .blockdev, .chardev:
            if let rdev = headers.rdev {
                archive_entry_set_rdev(writeEntry, rdev)
            }
        default:
            break
        }


        let result = archive_write_header(to.archive, writeEntry)
        if result != ARCHIVE_OK {
            throw .init(.writeArchive, msg:String(cString: archive_error_string(to.archive)))
        }

        return writeEntry
    }

    func loadArchive() async throws(ArkyveError) -> sending Archive {
        AKTrace("loadArchive() for \(path)")
        let archive = Archive(URL: self.url)
        let archiveFormat: libarchiveFormat
        let archiveFilters: [libarchiveFilter]
        let archiveEntries: [libarchiveHeader]

        do {
            (archiveFormat, archiveFilters, archiveEntries) = try await readEntriesFormatFilters()

            let entries = archiveEntries.map { ArchiveEntry($0) }
            AKTrace("loadArchive() found \(entries.count) entries")
            let (rootItems, remainingAll) = entries.filterBothwise {
                $0.path.countOccurrences(of: "/") == 0
            }
            let (remainingDirs, remainingFiles) = remainingAll.filterBothwise {
                $0.type == .directory
            }
            let root = ArchiveEntry(isRoot: true)

            var syntheticEntries: [ArchiveEntry] = []

            try root.addChildrenHierarchically(rootItems)
            syntheticEntries += try root.addChildrenHierarchically(remainingDirs)
            syntheticEntries += try root.addChildrenHierarchically(remainingFiles)

            let combinedEntries = entries + syntheticEntries
            archive.populate(root: root, entries: combinedEntries,
                             format: archiveFormat, filters: archiveFilters)


//#if DEBUG
//            await Task.sleep(2000000000)
//#endif
        } catch {
            throw error
        }

        AKTrace("Loaded archive with format \(archiveFormat) and filters \(archiveFilters)")
        return archive
    }

    @discardableResult func extract(_ extractableEntries: [ArchiveEntryExtractable],
                                    toFolder: URL, retainFullPath: Bool = false,
                                    archiveIsNew: Bool) async throws(ArkyveError) -> [URL] {
        var writtenURLs: [URL] = []

        writtenURLs += try await extractNonArchiveEntries(extractableEntries: extractableEntries,
                                                          toFolder: toFolder,
                                                          retainFullPath: retainFullPath)

        if archiveIsNew {
            // Archive has never been written to disk, so there's no need to proceed beyond here
            return writtenURLs
        }

        writtenURLs += try await extractEntries(extractableEntries,
                                                toFolder: toFolder,
                                                retainFullPath: retainFullPath)
        return writtenURLs
    }

    func extractNonArchiveEntries(extractableEntries: [ArchiveEntryExtractable],
                                  toFolder: URL,
                                  retainFullPath: Bool = false) async throws(ArkyveError) -> [URL] {
        var writtenURLs: [URL] = []

        // Ensure toFolder exists
        do {
            try FileManager.default.createDirectory(at: toFolder, withIntermediateDirectories: true)
        } catch { throw .init(.extract, msg: error.localizedDescription) }

        for extractableEntry in extractableEntries {
            let entryBasePath = extractableEntry.basePath
            for entry in extractableEntry.entries {
                var outputURL: URL
                if retainFullPath {
                    outputURL = toFolder.appendingPathComponent(entry.path)
                } else {
                    outputURL = toFolder.appendingPathComponent(
                        entry.path.deletingPrefix(entryBasePath))
                }

                do {
                    switch entry.source.type {
                    case .InMemory, .Synthetic:
                        if FileManager.default.fileExists(atPath: outputURL.path) {
                            try FileManager.default.removeItem(at: outputURL)
                        }

                        try FileManager.default.createDirectory(at: outputURL,
                                                                withIntermediateDirectories: true,
                                                                attributes: entry.fileManagerAttributes)
                        writtenURLs.append(outputURL)
                    case .Filesystem:
                        if FileManager.default.fileExists(atPath: outputURL.path) {
                            try FileManager.default.removeItem(at: outputURL)
                        }

                        if entry.header.type == .directory {
                            try FileManager.default.createDirectory(at: outputURL.deletingLastPathComponent(),
                                                                    withIntermediateDirectories: true,
                                                                    attributes: entry.fileManagerAttributes)
                        } else {
                            try FileManager.default.copyItem(atPath: entry.source.path, toPath: outputURL.path)
                        }
                        writtenURLs.append(outputURL)
                    case .Archive, .Root:
                        // These are someone else's responsibility
                        continue
                    }
                } catch {
                    throw .init(.extract, msg: error.localizedDescription)
                }
            }
        }

        return writtenURLs
    }

    struct ExtractPathMap {
        let outputURL: URL
        let entry: ArchiveEntryFlat
    }

    func extractEntries(_ extractableEntries: [ArchiveEntryExtractable],
                               toFolder: URL,
                               retainFullPath: Bool = false) async throws(ArkyveError) -> [URL] {
        var pathMap: [String: ExtractPathMap] = [:]
        var writtenURLs: [URL] = []
        var entryPtr: OpaquePointer?

        try readArchiveFD.openRead(path: path)
        defer { readArchiveFD.close() }

        // First create any synthetic directories we need to
        let synthPaths = extractableEntries.flatMap {
            $0.entries.filter { $0.isSynthesized == true }
        }
        for synthPath in synthPaths {
            let synthURL = toFolder.appendingPathComponent(synthPath.path)
            do {
                try FileManager.default.createDirectory(at: synthURL,
                                                        withIntermediateDirectories: true)
            } catch {
                throw .init(.extract, msg: error.localizedDescription)
            }
            writtenURLs.append(synthURL)
        }

        // Second, process the rest of the entries
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

                switch entry.source.type {
                case .InMemory, .Filesystem, .Synthetic, .Root:
                    // NOTE:
                    //  * Synthetic entries were handled above, before we got to this loop
                    //  * Root entry should never be written out
                    //  * InMemory/Filesystem entries are the responsibility of extractNonArchiveEntries
                    continue
                case .Archive:
                    pathMap[entry.source.path] = ExtractPathMap(outputURL: outputURL, entry: entry)
                }

            }
        }

        // Performance optimisation - if we don't have any .Archive entries left, don't bother
        if pathMap.count == 0 {
            return writtenURLs.sorted { $0.path < $1.path }
        }

        AKTrace("Extracting \(pathMap.count) entries to \(toFolder.path)")

        while archive_read_next_header(readArchiveFD.archive, &entryPtr) == ARCHIVE_OK {
            if let path = entryPath(entryPtr) {
                if pathMap.keys.contains(path) {
                    guard let exportPathMap = pathMap[path] else { continue }
                    let outputURL = exportPathMap.outputURL
                    let entryType = ArchiveEntryType(rawValue: archive_entry_filetype(entryPtr))

                    // Ensure all intermediate directories exist, incase we're extracting multiple levels of files that may not arrive in an order that guarantees their parent folder (synthetic or otherwise) is created first
                    do {
                        try FileManager.default.createDirectory(at: outputURL.deletingLastPathComponent(),
                                                                withIntermediateDirectories: true)
                    } catch {
                        throw .init(.extract, msg: error.localizedDescription)
                    }

                    switch entryType {
                    case .file:
                        // Ensure our file exists
                        let handle: FileHandle
                        do {
                            try Data().write(to: outputURL)
                            handle = try FileHandle(forWritingTo: outputURL)
                        } catch {
                            throw .init(.extract, msg: error.localizedDescription)
                        }
                        let result = archive_read_data_into_fd(
                            readArchiveFD.archive, handle.fileDescriptor)
                        if result != ARCHIVE_OK {
                            throw .init(.extract, msg: String(localized: "Unable to write to \(outputURL.path)"))
                        }
                        AKTrace("  Wrote \(outputURL.path(percentEncoded: false))")

                        writtenURLs.append(outputURL)
                    case .directory:
                        archive_read_data_skip(readArchiveFD.archive)
                        AKTrace("  Created \(outputURL.path(percentEncoded: false))")

                        writtenURLs.append(outputURL)
                    case .symlink:
                        let linkDest = String(cString: archive_entry_symlink(entryPtr))

                        do {
                            // Unlike Filemanager's createSymlink, symlink() can't auto-handle
                            // pre-existing files, so we will need to remove whatever exists at the
                            // path we want to write.
                            let linkExists = try? outputURL.checkResourceIsReachable()
                            if linkExists == true  {
                                try FileManager.default.removeItem(at: outputURL)
                            }

                            // NOTE: We can't use FileManager to create the symlink because it will fail when
                            // the target doesn't exist. We don't care if we're extracting a dangling symlink.
                            let res = symlink(linkDest.cString(using: .utf8), outputURL.path.cString(using: .utf8))
                            if res != 0 {
                                throw ArkyveError(.extract, msg: String(cString: strerror(errno)))
                            }

                            AKTrace("  Linked \(outputURL.path) to \(linkDest)")
                        } catch {
                            throw .init(.extract, msg: error.localizedDescription)
                        }

                        writtenURLs.append(outputURL)
                    default:
                        AKWarning(
                            "Skipping archive entry \(path) of type \(entryType.rawValue), it is an unsupported type"
                        )
                    }

                    do {
                        try FileManager.default.setAttributes(exportPathMap.entry.fileManagerAttributes,
                                                              ofItemAtPath: outputURL.path)
                    } catch {
                        AKWarning("Unable to set attributes on \(outputURL.path)")
                    }
                }
            }
        }

        return writtenURLs.sorted { $0.path < $1.path }
    }

    /// Write the archive to a URL
    /// - Parameters:
    ///   - headerMap: A dictionary containing path to ArchiveEntryFlat mappings. This determines the entries that will be written to the new archive
    ///   - to: A URL describing the filesystem location to write the archive to
    ///   - format: A libarchiveFormat describing the type of archive to write
    ///   - filters: An array of libarchiveFilter, describing which filters to apply to the archive
    func writeArchive(headerMap: [String: ArchiveEntryFlat],
                             to: URL,
                             format: libarchiveFormat,
                             filters: [libarchiveFilter],
                             skipRead: Bool = false) async throws(ArkyveError) {
        var headerMap = headerMap
        var result: Int32 = ARCHIVE_OK

        if !skipRead {
            try readArchiveFD.openRead(path: path)
        }
        defer { readArchiveFD.close() }

        var writeArchiveFD = libarchiveFD(type: .write)
        try writeArchiveFD.openWrite(at: to, format: format, filters: filters)
        defer { writeArchiveFD.close() }

        var readEntry: OpaquePointer?

        var rsize: size_t = size_t()
        var wsize: size_t = size_t()

        // First, examine the existing archive to find entries we need to copy over
        // (Except if skipRead is set)
        writeLoop: while (!skipRead && true) {
            var rbuf: UnsafeMutableRawPointer

            result = archive_read_next_header(readArchiveFD.archive, &readEntry)
            switch (result) {
            case ARCHIVE_OK:
                break
            case ARCHIVE_EOF:
                break writeLoop
            case ARCHIVE_FATAL:
                throw ArkyveError(.writeArchive, msg: String(localized: "Unable to read archive"))
            default:
                // FIXME: Why are we doing this?
                break writeLoop
            }

            guard let readEntryPath = entryPath(readEntry) else {
                throw ArkyveError(.entries, msg: String(localized: "Unabe to read archive entry path"))
            }

            // Find every entry in the tree that started out as this path, and in the archive
            // NOTE: We're not expecting to find multiple values here, but in the future we might want to offer the ability to duplicate a file within an archive
            let mapEntryKeys = headerMap.keys.filter {
                headerMap[$0]?.header.source.path == readEntryPath && headerMap[$0]?.header.source.type == .Archive
            }

            guard !mapEntryKeys.isEmpty else {
                // We no longer hold a reference to this entry, which means it's been deleted and we should discard its data
                archive_read_data_skip(readArchiveFD.archive)
                continue
            }

            // Grab the first mapEntryKey and allocate memory to read the entire data for that entry
            guard let mapEntryKey = mapEntryKeys.first,
                  let header = headerMap[mapEntryKey]?.header else {
                throw .init(.writeArchive, msg: String(localized: "Internal error: mapEntryKey not found"))
            }

            // Read the entire entry's data into the buffer so we can write it out multiple times if necessary
            rbuf = UnsafeMutableRawPointer.allocate(byteCount: Int(header.size), alignment: MemoryLayout<UInt8>.size)
            defer { rbuf.deallocate() }

            while true {
                rsize = archive_read_data(readArchiveFD.archive, rbuf, Int(header.size))
                if rsize == 0 {
                    rsize = Int(header.size)
                    break
                }
                if rsize < 0 {
                    throw .init(.writeArchive, msg: String(localized: "Failed to read source archive"))
                }
            }

            // Iterate over all of the keys that relate to this archive entry and write a new header/data section for each
            for mapEntryKey in mapEntryKeys {
                guard let header = headerMap[mapEntryKey]?.header else {
                    throw ArkyveError(.entries, msg: String(localized: "Unable to fetch entry header"))
                }

                // Read from archive and write to new archive
                let writeEntry = try writeArchiveEntryHeader(to: writeArchiveFD, headers: header)
                defer { archive_entry_free(writeEntry) }

                while true {
                    wsize = archive_write_data(writeArchiveFD.archive, rbuf, rsize)
                    if wsize == 0 {
                        wsize = rsize
                        break
                    }
                    if wsize < 0 {
                        let errorString = String(cString: archive_error_string(writeArchiveFD.archive))
                        throw .init(.writeArchive, msg: String(localized: "Failed to write data: \(errorString)"))
                    }
                }

                if Task.isCancelled {
                    throw .init(.cancelled, msg: "")
                }

                // Remove the headerMap value now we've processed it
                headerMap.removeValue(forKey: mapEntryKey)
            }

//#if DEBUG
//            try await Task.sleep(nanoseconds: 2000000000)
//#endif
        }

        // Second, process any filesystem-sourced entries that have been added to the archive
        for filePath in headerMap.keys.filter({ headerMap[$0]?.header.source.type == .Filesystem })
        {
            guard let flatEntry = headerMap[filePath] else {
                throw ArkyveError(.writeArchive, msg: String(localized: "Internal error: Header map inconsistency"))
            }

            // Write a header to the archive for this file
            let writeEntry = try writeArchiveEntryHeader(to: writeArchiveFD, headers: flatEntry.header)
            defer { archive_entry_free(writeEntry) }

            switch flatEntry.header.type {
            case .directory, .symlink, .blockdev, .chardev:
                // Nothing to do here, the header above is sufficient
                break
            case .socket, .fifo:
                // NOTE: These are pretty likely to never work when writing an archive, so there's nothing we can do here
                break
            case .unknown, .root:
                throw .init(.writeArchive, msg: String(localized: "Internal error: Attempted to write unexpected item: \(flatEntry.header.name)"))
            case .file:
                // Open the file from the filesystem if we can
                let fileHandle: FileHandle?
                do {
                    fileHandle = try FileHandle(forReadingFrom: URL(fileURLWithPath: flatEntry.header.source.path))
                } catch {
                    throw .init(.writeArchive, msg: String(localized: "Unable to open file: \(flatEntry.header.name) \(error.localizedDescription)"))
                }
                guard let fileHandle else {
                    throw .init(.writeArchive, msg: String(localized: "Failed to open file for reading: \(filePath)"))
                }
                defer { try? fileHandle.close() }

                // Read the file's data and write it to the archive
                while true {
                    let data: Data?
                    do {
                        data = try fileHandle.read(upToCount: 524288)
                    } catch {
                        throw .init(.writeArchive, msg: error.localizedDescription)
                    }
                    guard let data = data, !data.isEmpty else { break }

                    try? data.withUnsafeBytes { ptr in
                        let wsize = archive_write_data(writeArchiveFD.archive, ptr.baseAddress, data.count)
                        if wsize < 0 {
                            let errorString = String(cString: archive_error_string(writeArchiveFD.archive))
                            throw ArkyveError(.writeArchive, msg: String(localized: "Failed to write data: \(errorString)"))
                        }
                        if wsize != data.count {
                            throw ArkyveError(.writeArchive, msg: String(localized: "Size mismatch during write, expected \(data.count) bytes but wrote \(wsize) bytes"))
                        }
                    }
                }
            }

            if Task.isCancelled {
                throw .init(.cancelled, msg: "")
            }

            headerMap.removeValue(forKey: filePath)
        }

        // Third, process any InMemory-sourced folders that have been added to the archive
        for filePath in headerMap.keys.filter({ headerMap[$0]?.header.source.type == .InMemory && headerMap[$0]?.header.type == .directory })
        {
            guard let flatEntry = headerMap[filePath] else {
                throw ArkyveError(.writeArchive, msg: String(localized: "Internal error: header map inconsistency"))
            }

            // Write a header to the archive for this file
            let writeEntry = try writeArchiveEntryHeader(to: writeArchiveFD, headers: flatEntry.header)
            defer { archive_entry_free(writeEntry) }

            if Task.isCancelled {
                throw .init(.cancelled, msg: "")
            }

            headerMap.removeValue(forKey: filePath)
        }

        // FIXME: Deal with: do we have any headerMap entries left?
        if !headerMap.isEmpty {
            AKWarning(
                "Some entries were not processed during archive write: \(headerMap.keys.joined(separator: ", "))"
            )
        }

        writeArchiveFD.close()

        if let writeCacheURL = writeArchiveFD.writeCacheURL {
            AKTrace("Moving archive cache to final destination: \(writeCacheURL) -> \(to)")
            do {
                _ = try FileManager.default.replaceItemAt(to, withItemAt: writeCacheURL, options: [.usingNewMetadataOnly])
            } catch {
                do {
                    try FileManager.default.moveItem(at: writeCacheURL, to: to)
                } catch {
                    throw .init(.writeArchive, msg: error.localizedDescription)
                }
            }
        }
    }
}
