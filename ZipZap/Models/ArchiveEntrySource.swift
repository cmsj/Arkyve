//
//  ArchiveEntrySource.swift
//  ZipZap
//
//  Created by Chris Jones on 26/12/2024.
//

enum ArchiveEntrySourceType {
    case Archive
    case Filesystem
    case Root
    case Synthetic
}

struct ArchiveEntrySource {
    let type: ArchiveEntrySourceType
    let path: String
}
