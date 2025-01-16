//
//  libarchiveFormat.swift
//  ZipZap
//
//  Created by Chris Jones on 03/10/2024.
//

enum libarchiveFormat: Int32, CaseIterable, Identifiable {
    var id: RawValue { rawValue }

    case Unknown = 0x0
    case CPIO = 0x10000
    case CPIO_POSIX = 0x10001
    case CPIO_BIN_LE = 0x10002
    case CPIO_BIN_BE = 0x10003
    case CPIO_SVR4_NOCRC = 0x10004
    case CPIO_SVR4_CRC = 0x10005
    case CPIO_AFIO_LARGE = 0x10006
    case CPIO_PWB = 0x10007
    case SHAR = 0x20000
    case SHAR_BASE = 0x20001
    case SHAR_DUMP = 0x20002
    case TAR = 0x30000
    case TAR_USTAR = 0x30001
    case TAR_PAX_INTERCHANGE = 0x30002
    case TAR_PAX_RESTRICTED = 0x30003
    case TAR_GNUTAR = 0x30004
    case ISO9660 = 0x40000
    case ISO9660_RR = 0x40001
    case ZIP = 0x50000
    case Empty = 0x60000
    case AR = 0x70000
    case AR_GNU = 0x70001
    case AR_BSD = 0x70002
    case MTREE = 0x80000
    case RAW = 0x90000
    case XAR = 0xA0000
    case LHA = 0xB0000
    case CAB = 0xC0000
    case RAR = 0xD0000
    case _7ZIP = 0xE0000
    case WARC = 0xF0000
    case RAR_V5 = 0x100000

    var canWrite: Bool {
        get {
            switch (self) {
                // NOTE: These are not the only formats libarchive can write, but they are all I care to test
            case .TAR, .TAR_GNUTAR, .ISO9660, .ISO9660_RR, .ZIP, ._7ZIP:
                true
            default:
                false
            }
        }
    }
}

extension libarchiveFormat: Comparable {
    static func <(lhs: Self, rhs: Self) -> Bool {
        return lhs.rawValue < rhs.rawValue
    }
}

extension libarchiveFormat: CustomStringConvertible {
    var description: String {
        get {
            switch (self) {
            case .Unknown: return "Unknown"
            case .CPIO: return "CPIO"
            case .CPIO_POSIX: return "CPIO_POSIX"
            case .CPIO_BIN_LE: return "CPIO_BIN_LE"
            case .CPIO_BIN_BE: return "CPIO_BIN_BE"
            case .CPIO_SVR4_NOCRC: return "CPIO_SVR4_NOCRC"
            case .CPIO_SVR4_CRC: return "CPIO_SVR4_CRC"
            case .CPIO_AFIO_LARGE: return "CPIO_AFIO_LARGE"
            case .CPIO_PWB: return "CPIO_PWB"
            case .SHAR: return "SHAR"
            case .SHAR_BASE: return "SHAR_BASE"
            case .SHAR_DUMP: return "SHAR_DUMP"
            case .TAR: return "BSD tar"
            case .TAR_USTAR: return "TAR_USTAR"
            case .TAR_PAX_INTERCHANGE: return "TAR_PAX_INTERCHANGE"
            case .TAR_PAX_RESTRICTED: return "TAR_PAX_RESTRICTED"
            case .TAR_GNUTAR: return "GNU tar"
            case .ISO9660: return "ISO9660"
            case .ISO9660_RR: return "ISO9660 Rock Ridge"
            case .ZIP: return "Zip"
            case .Empty: return "Empty"
            case .AR: return "AR"
            case .AR_GNU: return "AR_GNU"
            case .AR_BSD: return "AR_BSD"
            case .MTREE: return "MTREE"
            case .RAW: return "RAW"
            case .XAR: return "XAR"
            case .LHA: return "LHA"
            case .CAB: return "CAB"
            case .RAR: return "RAR"
            case ._7ZIP: return "7Zip"
            case .WARC: return "WARC"
            case .RAR_V5: return "RAR_V5"
            }
        }
    }
}
