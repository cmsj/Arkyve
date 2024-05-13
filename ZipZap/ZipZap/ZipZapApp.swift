//
//  ZipZapApp.swift
//  ZipZap
//
//  Created by Chris Jones on 10/05/2024.
//

import SwiftUI
import zzarchive

@main
struct ZipZapApp: App {
//    init() {
//        let archive = archive_read_new()
//        var entry: OpaquePointer?
//
//        archive_read_support_filter_all(archive)
//        archive_read_support_format_all(archive)
//
//        let ptr = archive_read_open_filename(archive, "/tmp/1Password.zip", 10240)
//        if ptr != ARCHIVE_OK {
//            print(String(cString: archive_error_string(archive)))
//            print(errno)
//            fatalError("Unable to open archive")
//        }
//
//        while (archive_read_next_header(archive, &entry) == ARCHIVE_OK) {
//            print("\(String(describing: archive_entry_pathname(entry)))")
//            archive_read_data_skip(archive)
//        }
//        archive_read_free(archive)
//    }
    var body: some Scene {
        WindowGroup {
            ContentView()
        }
    }
}
