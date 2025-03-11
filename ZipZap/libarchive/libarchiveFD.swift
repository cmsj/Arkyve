//
//  libarchiveFDType.swift
//  ZipZap
//
//  Created by Chris Jones on 31/12/2024.
//

import ZZLog

enum libarchiveFDType {
    case read
    case write
}

struct libarchiveFD {
    var fd: Int32 = -1
    var archive: OpaquePointer? = nil
    var type: libarchiveFDType = .read
    var writeCacheURL: URL? = nil

    mutating func close() {
        switch type {
        case .read:
            self.closeRead()
        case .write:
            self.closeWrite()
        }
        archive = nil
        fd = -1
    }

    mutating private func closeRead() {
        if archive != nil {
            archive_read_close(archive)
            archive_read_free(archive)
        }
        if fd >= 0 {
            Darwin.close(fd)
        }
    }

    mutating private func closeWrite() {
        if archive != nil {
            archive_write_close(archive)
            archive_write_free(archive)
        }
    }

    mutating func openRead(path: String) throws(ArchiveError) {
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
            self.close()
            throw ArchiveError.ArchiveOpenError(archive: path, error: "open() failed: \(errno)")
        }

        let ptr = archive_read_open_fd(archive, fd, 10240)
        if ptr != ARCHIVE_OK {
            let errStr = String(cString: archive_error_string(archive))
            self.close()
            throw ArchiveError.ArchiveOpenError(archive: path, error:errStr)
        }
    }
    
    mutating func openWrite(at: URL, format: libarchiveFormat, filters: [libarchiveFilter]) throws(ArchiveError) {
        var result: Int32

        archive = archive_write_new()
        if (archive == nil) {
            throw ArchiveError.ArchiveWriteError(archive: at.path, error: "Unable to allocate memory")
        }

        result = archive_write_set_format(archive, format.rawValue)
        if (result != ARCHIVE_OK) {
            throw ArchiveError.ArchiveWriteError(archive: at.path, error: "Unable to set format: \(String(describing: archive_error_string(archive)))")
        }

        for filter in filters {
            result = archive_write_add_filter(archive, filter.rawValue)
            if (result != ARCHIVE_OK) {
                throw ArchiveError.ArchiveWriteError(archive: at.path, error: "Unable to add filter: \(String(describing: archive_error_string(archive)))")
            }
        }

        // Figure out cache filename
        writeCacheURL = SettingsManager.shared.writeCacheURL.appendingPathComponent(at.lastPathComponent)
        guard let writeCachePath = writeCacheURL else {
            throw ArchiveError.ArchiveWriteError(archive: at.path, error: "Unable to create cache path")
        }

        #ZZTrace("Archive write cache: \(writeCachePath.path)")

        result = archive_write_open_filename(archive, writeCachePath.path)
        if (result != ARCHIVE_OK) {
            throw ArchiveError.ArchiveWriteError(archive: at.path, error: "Unable to open output archive: \(String(describing: archive_error_string(archive)))")
        }
    }
}
