//
//  libarchiveFDType.swift
//  Arkyve
//
//  Created by Chris Jones on 31/12/2024.
//

/// Represents the type of file descriptor operation for libarchive.
enum libarchiveFDType {
    /// Indicates a read operation on the archive.
    case read
    /// Indicates a write operation on the archive.
    case write
}

/// A wrapper around libarchive's file descriptor operations.
///
/// This struct manages the lifecycle of libarchive file descriptors and provides
/// methods for opening and closing archives for both read and write operations.
struct libarchiveFD {
    /// The file descriptor number, -1 if not open.
    var fd: Int32 = -1
    /// The libarchive archive pointer.
    var archive: OpaquePointer? = nil
    /// The type of operation being performed.
    var type: libarchiveFDType = .read
    /// The URL for the write cache file.
    var writeCacheURL: URL? = nil

    /// Closes the archive and cleans up resources.
    ///
    /// This method handles both read and write operations, ensuring proper cleanup
    /// of system resources and libarchive structures.
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

    /// Closes a read operation and frees associated resources.
    ///
    /// This method handles the cleanup of read-specific resources including
    /// the libarchive read structures and file descriptor.
    mutating private func closeRead() {
        if archive != nil {
            archive_read_close(archive)
            archive_read_free(archive)
        }
        if fd >= 0 {
            Darwin.close(fd)
        }
    }

    /// Closes a write operation and frees associated resources.
    ///
    /// This method handles the cleanup of write-specific resources including
    /// the libarchive write structures.
    mutating private func closeWrite() {
        if archive != nil {
            archive_write_close(archive)
            archive_write_free(archive)
        }
    }

    /// Opens an archive for reading.
    ///
    /// - Parameter path: The path to the archive file to open.
    /// - Throws: `ArchiveError.ArchiveOpenError` if the archive cannot be opened
    ///          or if memory allocation fails.
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
    
    /// Opens an archive for writing.
    ///
    /// - Parameters:
    ///   - at: The URL where the archive will be written.
    ///   - format: The format to use for the archive.
    ///   - filters: An array of filters to apply to the archive.
    /// - Throws: `ArchiveError.ArchiveWriteError` if the archive cannot be created
    ///          or if memory allocation fails.
    mutating func openWrite(at: URL, format: libarchiveFormat, filters: [libarchiveFilter]) throws(ArchiveError) {
        var result: Int32

        archive = archive_write_new()
        if (archive == nil) {
            throw ArchiveError.ArchiveWriteError(archive: at.path, error: "Unable to allocate memory")
        }

        result = archive_write_set_format(archive, format.rawValue)
        if (result != ARCHIVE_OK) {
            let errorString = String(cString: archive_error_string(archive))
            throw ArchiveError.ArchiveWriteError(archive: at.path, error: "Unable to set format: \(errorString)")
        }

        for filter in filters {
            result = archive_write_add_filter(archive, filter.rawValue)
            if (result != ARCHIVE_OK) {
                let errorString = String(cString: archive_error_string(archive))
                throw ArchiveError.ArchiveWriteError(archive: at.path, error: "Unable to add filter: \(errorString)")
            }
        }

        // Figure out cache filename
        writeCacheURL = SettingsManager.shared.writeCacheURL.appendingPathComponent(at.lastPathComponent)
        guard let writeCachePath = writeCacheURL else {
            throw ArchiveError.ArchiveWriteError(archive: at.path, error: "Unable to create cache path")
        }

        AKTrace("Archive write cache: \(writeCachePath.path)")

        result = archive_write_open_filename(archive, writeCachePath.path.cString(using: .utf8))
        if (result != ARCHIVE_OK) {
            let errorString = String(cString: archive_error_string(archive))
            throw ArchiveError.ArchiveWriteError(archive: at.path, error: "Unable to open output archive: \(errorString)")
        }
    }
}
