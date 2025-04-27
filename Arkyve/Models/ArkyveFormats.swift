//
//  ArkyveFormats.swift
//  Arkyve
//
//  Created by Chris Jones on 27/04/2025.
//


import UniformTypeIdentifiers

enum ArkyveFormats: Int32, Identifiable, CaseIterable {
    var id: RawValue { rawValue }

    // Order matters here, because NSSavePanel will show the order we select here (after filtering it to saveable formats)
    case zip
    case _7z
    case iso
    case targz
    case tarbz2
    case tar

    case cpio
    case warc
    case xar
    case xip
    case pkg
    case cab
    case shar
    case ar
    case lha
    case lzh
    case rar
    case raw
    case gz
    case bz2

    var description: String {
        switch self {
        case .tar:
            "tar Archive"
        case .targz:
            "tar Archive (GZip)"
        case .tarbz2:
            "tar Archive (BZip2)"
        case .zip:
            "Zip Archive"
        case ._7z:
            "7Zip Archive"
        case .iso:
            "ISO Image"
        case .cpio:
            "CPIO Archive"
        case .shar:
            "Shell Archive"
        case .ar:
            "Library Archive"
        case .xar:
            "eXtensible Archive"
        case .xip:
            "Secure Archive"
        case .pkg:
            "Installer Package"
        case .lha:
            "LHA Archive"
        case .lzh:
            "LZH Archive"
        case .cab:
            "Cabinet Archive"
        case .rar:
            "RAR Archive"
        case .warc:
            "Web Archive"
        case .gz:
            "GZip Archive"
        case .bz2:
            "BZip2 Archive"
        case .raw:
            "Raw File"
        }
    }

    var ext: String {
        switch self {
        case .tar:
            "tar"
        case .targz:
            "tgz" // FIXME: No
        case .tarbz2:
            "tbz2" // FIXME: No
        case .zip:
            "zip"
        case ._7z:
            "7z"
        case .iso:
            "iso"
        case .cpio:
            "cpio"
        case .shar:
            "sh"
        case .ar:
            "a"
        case .xar:
            "xar"
        case .xip:
            "xip"
        case .pkg:
            "pkg"
        case .lha:
            "lha"
        case .lzh:
            "lzh"
        case .cab:
            "cab"
        case .rar:
            "rar"
        case .warc:
            "webarchive"
        case .gz:
            "gz"
        case .bz2:
            "bz2"
        case .raw:
            ""
        }
    }

    var canWrite: Bool {
        switch self {
            // FIXME: Can we enable write support for more formats?
        case .tar, .targz, .tarbz2, .zip, ._7z, .iso, .cpio, .xar:
            true
        default:
            false
        }
    }

    var libarchiveFormat: libarchiveFormat {
        switch self {
        case .tar:
            .TAR_GNUTAR
        case .targz:
            .TAR_GNUTAR
        case .tarbz2:
            .TAR_GNUTAR
        case .zip:
            .ZIP
        case ._7z:
            ._7ZIP
        case .iso:
            .ISO9660
        case .cpio:
            .CPIO
        case .shar:
            .SHAR
        case .ar:
            .AR
        case .xar:
            .XAR
        case .xip:
            .XAR
        case .pkg:
            .XAR
        case .lha:
            .LHA
        case .lzh:
            .LHA
        case .cab:
            .CAB
        case .rar:
            .RAR
        case .warc:
            .WARC
        case .gz, .bz2, .raw:
            .RAW
        }
    }

    var utType: UTType? {
        switch self {
        case .zip:
                .zip
        case .tar:
                .tarArchive
        case .warc:
                .webArchive
        case .gz:
                .gzip
        case .bz2:
                .bz2
        case ._7z:
                ._7z
        case .iso:
                .iso
        case .cpio:
                .cpio
        case .xar:
                .xar
        case .xip:
                .xip
        case .pkg:
                .pkg
        case .cab:
                .cab
        case .targz:
                .targz
        case .tarbz2:
                .tarbz2
        case .ar:
                .ar
        case .lha:
                .lha
        case .lzh:
                .lzh
        case .rar:
                .rar
        default:
            nil
        }
    }
    var libarchiveFilters: [libarchiveFilter] {
        switch self {
        case .targz, .gz:
            [.GZip]
        case .tarbz2, .bz2:
            [.BZip2]
        default:
            [.None]
        }
    }

    static var writeableCases: [ArkyveFormats] {
        get {
            ArkyveFormats.allCases.filter { $0.canWrite }
        }
    }

    static var writeableUTTypes: [UTType] {
        ArkyveFormats.writeableCases.compactMap {
            $0.utType
        }
    }

    static var utTypes: [UTType] {
        ArkyveFormats.allCases.compactMap {
            $0.utType
        }
    }

    static func initFromlibarchiveFormat(_ format: libarchiveFormat, withFilters filters: [libarchiveFilter] = []) -> ArkyveFormats {
        switch format {
        case .TAR_GNUTAR:
            if filters.first == .BZip2 {
                return .tarbz2
            } else if filters.isEmpty || filters == [.None] {
                return .tar
            }
            return .targz
        case .RAW:
            switch (filters.first) {
            case .BZip2:
                return .bz2
            case .GZip:
                return .gz
            default:
                return .raw
            }
        case .ZIP:
            return .zip
        case ._7ZIP:
            return ._7z
        case .ISO9660:
            return .iso
        default:
            return .zip
        }
    }

    static func initFromUTType(_ type: UTType?) -> ArkyveFormats? {
        guard type != nil else { return nil }

        switch (type) {
        case .ar:
            return .ar
        case .zip:
            return .zip
        case ._7z:
            return ._7z
        case .tarArchive:
            return .tar
        case .targz:
            return .targz
        case .tarbz2:
            return .tarbz2
        case .iso:
            return .iso
        case .lha:
            return .lha
        case .lzh:
            return .lzh
        case .rar:
            return .rar
        case .cab:
            return .cab
        case .cpio:
            return .cpio
        case .xar:
            return .xar
        case .xip:
            return .xip
        case .pkg:
            return .pkg

        default:
            return nil
        }
    }
}
