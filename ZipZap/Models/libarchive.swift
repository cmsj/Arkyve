//
//  libarchive.swift
//  ZipZap
//
//  Created by Chris Jones on 11/06/2024.
//

import Foundation
import SwiftUI
import ZZLog

struct libarchiveEntry: Identifiable {
    let id = UUID()
    let isSynthesized = false
    let type: ArchiveEntryType

    let path: String
    let name: String
    let pathComponents: [String]
    let size: Int64

    let atime: Date
    let ctime: Date
    let mtime: Date
    let btime: Date

    let uid: String
    let gid: String

    let perms: String

    var sizeString: String {
        get { size != -1 ? String(size) : "--" }
    }
    var finalDirName: String? {
        get {
            if type == .directory {
                return name
            }
            return pathComponents.dropLast().last
        }
    }
}

enum libarchiveFormat: Int32 {
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

enum libarchiveFilter: Int32 {
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

actor libarchive {
    private var fd: Int32 = -1
    private var archive: OpaquePointer? = nil

    private var path: String
    private(set) var entries: [libarchiveEntry] = []
    private(set) var format: libarchiveFormat = .Unknown
    private(set) var filters: [libarchiveFilter] = []

    init(path: String) {
        self.path = path
    }
    
    init(url: URL) {
        self.path = url.path(percentEncoded: false)
    }

    private func open() throws {
        if fd >= 0 || archive != nil {
            close()
        }

        // Prepare libarchive's data structure
        archive = archive_read_new()
        if archive == nil {
            throw ArchiveError.ArchiveOpenError("Unable to allocate archive memory")
        }
        archive_read_support_filter_all(archive)
        archive_read_support_format_all(archive)

        fd = Darwin.open(path, O_RDONLY)
        if fd < 0 {
            close()
            throw ArchiveError.ArchiveOpenError("Unable to open \(path): \(errno)")
        }

        let ptr = archive_read_open_fd(archive, fd, 10240)
        if ptr != ARCHIVE_OK {
            let errStr = String(cString: archive_error_string(archive))
            close()
            throw ArchiveError.ArchiveOpenError("Unable to open archive (\(ptr)): \(errStr)")
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

    private func readEntries() throws -> [libarchiveEntry] {
        guard archive != nil else {
            throw ArchiveError.ArchiveEntriesError("libarchive_entries() called on a nil archive")
        }

        var entries: [libarchiveEntry] = []

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

            if var pathString = entryPath(entry) {
                if pathString.last == "/" {
                    pathString = String(pathString.dropLast())
                }
                let pathBits = pathString.split(separator: "/").map(String.init)

                path = pathString
                name = pathBits.last ?? "Unknown"
                pathComponents = pathBits
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

            if archive_entry_atime_is_set(entry) != 0 {
                atime = Date(since: archive_entry_atime(entry))
            } else {
                atime = Date(since: 0)
            }

            if archive_entry_ctime_is_set(entry) != 0 {
                ctime = Date(since: archive_entry_ctime(entry))
            } else {
                ctime = Date(since: 0)
            }

            if archive_entry_mtime_is_set(entry) != 0 {
                mtime = Date(since: archive_entry_mtime(entry))
            } else {
                mtime = Date(since: 0)
            }

            if archive_entry_birthtime_is_set(entry) != 0 {
                btime = Date(since: archive_entry_birthtime(entry))
            } else {
                btime = Date(since: 0)
            }

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

            entries.append(libarchiveEntry(type: type, path: path, name: name, pathComponents: pathComponents, size: size, atime: atime, ctime: ctime, mtime: mtime, btime: btime, uid: uid, gid: gid, perms: perms))
        }

        return entries
    }

    private func readFormatFilters() {
        format = libarchiveFormat(rawValue: archive_format(archive)) ?? .Unknown

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

    func readEntriesFormatFilters() throws -> (libarchiveFormat, [libarchiveFilter], [libarchiveEntry]) {
        try open()
        defer { close() }

        entries = try readEntries()
        readFormatFilters()

        return (self.format, self.filters, self.entries)
    }

    func extractEntries(_ paths: [String], toFolder: URL) throws -> [URL] {
        var writtenURLs: [URL] = []
        var entryPtr: OpaquePointer?

        try open()
        defer { close() }

        while (archive_read_next_header(archive, &entryPtr) == ARCHIVE_OK) {
            if let path = entryPath(entryPtr) {
                if paths.contains(path) {
                    let outputURL = toFolder.appendingPathComponent(path)
                    let entryType = ArchiveEntryType(rawValue: archive_entry_filetype(entryPtr))
                    switch entryType {
                    case .file:
                        // Ensure all intermediate directories exist, incase we're extracting multiple levels of files that may not arrive in an order that guarantees their parent folder (synthetic or otherwise) is created first
                        try FileManager.default.createDirectory(at: outputURL.deletingLastPathComponent(), withIntermediateDirectories: true)

                        // Ensure our file exists
                        try Data().write(to: outputURL)
                        let handle = try FileHandle(forWritingTo: outputURL)
                        let result = archive_read_data_into_fd(archive, handle.fileDescriptor)
                        if result != ARCHIVE_OK {
                            throw ArchiveError.ArchiveExtractError("Unable to write to \(outputURL.path(percentEncoded: false))")
                        }

                        writtenURLs.append(outputURL)
                    case .directory:
                        try FileManager.default.createDirectory(at: outputURL, withIntermediateDirectories: true)
                        archive_read_data_skip(archive)

                        writtenURLs.append(outputURL)
                    case .symlink:
                        // FIXME: This is untested, doubly so its ability to produce directory symlinks (if that even makes a difference on macOS)
                        let linkDest = String(cString: archive_entry_symlink(entryPtr))
                        let linkDestURL = Foundation.URL(fileURLWithPath: linkDest, isDirectory: archive_entry_symlink_type(entryPtr) == AE_SYMLINK_TYPE_DIRECTORY)
                        try FileManager.default.createSymbolicLink(at: outputURL, withDestinationURL: linkDestURL)
                    default:
                        #ZZError("UNSUPPORTED TYPE: \(entryType.rawValue)")
                    }

                    // FIXME: Having extracted something, we probably ought to set its permissions
                }
            }
        }

        return writtenURLs
    }

    func createArchive(to: URL, format: libarchiveFormat, filters: [libarchiveFilter], entries: [libarchiveEntry]) throws {
        try saveArchive(from: nil, to: to, format: format, filters: filters, entries: entries)
    }

    func saveArchive(from: URL?, to: URL, format: libarchiveFormat, filters: [libarchiveFilter], entries: [libarchiveEntry]) throws {
        let writeArchive = archive_write_new()
        archive_write_set_format(writeArchive, format.rawValue)
        for filter in filters {
            archive_write_add_filter(writeArchive, filter.rawValue)
        }
        
    }
}
