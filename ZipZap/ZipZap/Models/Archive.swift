//
//  Archive.swift
//  ZipZap
//
//  Created by Chris Jones on 10/05/2024.
//

import Foundation
import Combine
import os
import zzarchive

class Archive : ObservableObject {
    private static let logger = Logger(
        subsystem: Bundle.main.bundleIdentifier!,
        category: String(describing: Archive.self)
    )

    var URL: URL
    @Published var name: String
    @Published var entries: [ArchiveEntry] = []
    @Published var error: String? = nil
    private var archive: OpaquePointer? = nil

    init(name: String, URL: URL) {
        self.URL = URL
        self.name = URL.lastPathComponent
        Self.logger.trace("Initialised for \(self.URL)")
    }

    init() {
        self.URL = Foundation.URL(fileURLWithPath: "")
        self.name = ""
    }

    deinit {
        guard self.archive != nil else { return }
        self.close()
    }

    private func open() {
        let filepath = self.URL.path()

        DispatchQueue.global(qos: .userInitiated).async {
            var entry: OpaquePointer?
            Self.logger.trace("Opening: \(filepath)")

            // Prepare libarchive's data structure
            self.archive = archive_read_new()
            archive_read_support_filter_all(self.archive)
            archive_read_support_format_all(self.archive)

            let ptr = archive_read_open_filename(self.archive, filepath, 10240)
            if ptr != ARCHIVE_OK {
                DispatchQueue.main.async {
                    self.error = String(cString: archive_error_string(self.archive))
                }
                Self.logger.error("Unable to open \(filepath)")
                archive_read_free(self.archive)
                return
            }

            while (archive_read_next_header(self.archive, &entry) == ARCHIVE_OK) {
                if let newEntry = ArchiveEntry(entry) {
                    DispatchQueue.main.async {
                        self.entries.append(newEntry)
                    }
                }
                archive_read_data_skip(self.archive)
            }
        }
    }

    private func close() {
        DispatchQueue.global(qos: .userInitiated).async {
            archive_read_free(self.archive)
            DispatchQueue.main.async {
                self.URL = Foundation.URL(fileURLWithPath: "")
                self.name = ""
                self.entries = []
            }
        }
    }

    func setURL(_ url: URL) {
        self.URL = url
        self.name = URL.lastPathComponent
        self.close() // We might already have an archive, and this is safe to call if not
        self.open()
    }
}
