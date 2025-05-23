//
//  ArchiveEntryFlat.swift
//  Arkyve
//
//  Created by Chris Jones on 23/12/2024.
//

import Foundation

struct ArchiveEntryFlat: Codable {
    let path: String
    let isSynthesized: Bool
    let header: libarchiveHeader
    let source: ArchiveEntrySource

    var fileManagerAttributes: [FileAttributeKey: Any] {
        var attributes: [FileAttributeKey: Any] = [:]

        attributes[.creationDate] = header.btime
        attributes[.modificationDate] = header.mtime
        attributes[.posixPermissions] = header.perms as NSNumber
        // It would be nice to set UID/GID, but that requires root
        //        attributes[.ownerAccountID] = self.uid as NSNumber
        //        attributes[.groupOwnerAccountID] = self.gid as NSNumber

        return attributes
    }
}
