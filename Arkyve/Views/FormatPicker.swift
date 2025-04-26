//
//  FormatPicker.swift
//  Arkyve
//
//  Created by Chris Jones on 16/01/2025.
//

import SwiftUI
import UniformTypeIdentifiers

// FIXME: Move ArkyveFormats into its own file
// FIXME: Move this UTType stuff into Extensions
// FIXME: Finish adding Document types in Info.plist
// FIXME: Figure out if we can add .gz and .bz2 types, to open such files
// FIXME: Remove FormatPicker
// FIXME: Audit libarchiveFormat for simplification now ArkyveFormats exists
// FIXME: Audit FormatPicketViewModel - it's now just a delgate for NSSavePanel?

extension UTType {
    static var targz: UTType { UTType(exportedAs: "net.tenshu.Arkyve.targz") }
    static var tarbz2: UTType { UTType(exportedAs: "net.tenshu.Arkyve.tarbz2") }
    static var ar: UTType { UTType(exportedAs: "net.tenshu.Arkyve.ar") }
    static var lha: UTType { UTType(exportedAs: "net.tenshu.Arkyve.lha") }
    static var lzh: UTType { UTType(exportedAs: "net.tenshu.Arkyve.lzh") }
    static var rar: UTType { UTType(importedAs: "com.rarlab.rar-archive") }
    static var cab: UTType { UTType(importedAs: "com.microsoft.cab") }
}

enum ArkyveFormats: Int32, Identifiable, CaseIterable {
    var id: RawValue { rawValue }

    case tar
    case zip
    case _7z
    case iso
    case cpio
    case warc
    case xar
    case xip
    case pkg
    case cab

    case shar
    case ar
    case targz
    case tarbz2
    case lha
    case lzh
    case rar

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
        }
    }

    var ext: String {
        switch self {
        case .tar:
            "tar"
        case .targz:
            "tar.gz"
        case .tarbz2:
            "tar.bz2"
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
        }
    }

    var canWrite: Bool {
        switch self {
        case .tar, .targz, .tarbz2, .zip, ._7z, .iso:
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
        case ._7z:
            UTType("org.7-zip.7-zip-archive")
        case .iso:
            UTType("public.iso-image")
        case .cpio:
            UTType("public.cpio-archive")
        case .xar:
            UTType("com.apple.xar-archive")
        case .xip:
            UTType("com.apple.xip-archive")
        case .pkg:
            UTType("com.apple.installer-package-archive")
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
        case .targz:
            [.GZip]
        case .tarbz2:
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
}

struct FormatPicker: View {
    @Environment(\.formatPickerViewModel) var viewModel: FormatPickerViewModel

    var body: some View {
        @Bindable var viewModel = viewModel

        HStack {
            Picker(selection: $viewModel.format, label: Text("Format")) {
                ForEach(ArkyveFormats.allCases) { format in
                    Text(format.description)
                        .tag(format)
                }
            }
            .padding()
        }
    }
}
