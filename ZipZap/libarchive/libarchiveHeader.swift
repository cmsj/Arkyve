//
//  libarchiveHeader.swift
//  ZipZap
//
//  Created by Chris Jones on 22/12/2024.
//


struct libarchiveHeader: Identifiable {
    let id = UUID()
    let source: ArchiveEntrySource
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

    let perms: mode_t

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
