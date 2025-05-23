//
//  ArchiveEntryType.swift
//  Arkyve
//
//  Created by Chris Jones on 22/12/2024.
//

import Darwin.sys

extension ArchiveEntryType: CaseIterable {
    public static var allCases: [ArchiveEntryType] {
        [.unknown, .file, .directory, .socket, .symlink, .chardev, .blockdev, .fifo, .root]
    }
}

enum ArchiveEntryType: String, Codable {
    case unknown = "questionmark"
    case file = "doc"
    case directory = "folder"
    case socket = "gearshape.2"
    case symlink = "link"
    case chardev = "chart.bar.doc.horizontal"
    case blockdev = "batteryblock"
    case fifo = "pipe.and.drop"
    case root = "virtual root"

    init(rawValue: mode_t) {
        switch (S_IFMT & rawValue) {
        case S_IFREG:
            self = .file
        case S_IFDIR:
            self = .directory
        case S_IFSOCK:
            self = .socket
        case S_IFLNK:
            self = .symlink
        case S_IFCHR:
            self = .chardev
        case S_IFBLK:
            self = .blockdev
        case S_IFIFO:
            self = .fifo
        default:
            self = .unknown
        }
    }

    var userString: String {
        get {
            switch (self) {
            case .unknown:
                "Unknown"
            case .file:
                "File"
            case .directory:
                "Folder"
            case .socket:
                "Socket"
            case .symlink:
                "Symlink"
            case .chardev:
                "Char dev"
            case .blockdev:
                "Block dev"
            case .fifo:
                "FIFO"
            case .root:
                ""
            }
        }
    }
}
