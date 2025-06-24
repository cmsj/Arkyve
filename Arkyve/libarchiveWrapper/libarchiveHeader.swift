//
//  libarchiveHeader.swift
//  Arkyve
//
//  Created by Chris Jones on 22/12/2024.
//

import Foundation

struct libarchiveHeader: Identifiable, Codable {
    let id: UUID
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

    let uid: Int64?
    let gid: Int64?

    let perms: mode_t

    var symlinkTarget: String? = nil
    var rdev: dev_t? = nil

    let isEncrypted: Bool

    init(id: UUID = UUID(), source: ArchiveEntrySource, type: ArchiveEntryType, path: String, name: String,
         pathComponents: [String], size: Int64, atime: Date, ctime: Date, mtime: Date, btime: Date,
         uid: Int64?, gid: Int64?, perms: mode_t, symlinkTarget: String? = nil, rdev: dev_t? = nil,
         isEncrypted: Bool = false) {
        self.id = id
        self.source = source
        self.type = type
        self.path = path
        self.name = name
        self.pathComponents = pathComponents
        self.size = size
        self.atime = atime
        self.ctime = ctime
        self.mtime = mtime
        self.btime = btime
        self.uid = uid
        self.gid = gid
        self.perms = perms
        self.symlinkTarget = symlinkTarget
        self.rdev = rdev
        self.isEncrypted = isEncrypted
    }
}
