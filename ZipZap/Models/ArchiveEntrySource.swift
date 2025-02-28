//
//  ArchiveEntrySource.swift
//  ZipZap
//
//  Created by Chris Jones on 26/12/2024.
//

enum ArchiveEntrySourceType: Codable {
    case Archive
    case Filesystem
    case Root
    case Synthetic
}

struct ArchiveEntrySource: Codable {
    let type: ArchiveEntrySourceType
    let path: String
}
