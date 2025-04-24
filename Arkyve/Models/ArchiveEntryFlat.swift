//
//  ArchiveEntryFlat.swift
//  Arkyve
//
//  Created by Chris Jones on 23/12/2024.
//


struct ArchiveEntryFlat: Codable {
    let path: String
    let isSynthesized: Bool
    let header: libarchiveHeader
}
