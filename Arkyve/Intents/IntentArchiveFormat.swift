//
//  IntentArchiveFormat.swift
//  Arkyve
//
//  Created by Chris Jones on 13/06/2025.
//

import AppIntents

enum IntentArchiveFormat: String, Codable, Sendable, AppEnum {
    case tar
    case targz
    case tarbz2
    case tarxz
    case zip
    case _7z
    case iso
    case cpio
    case xar

    static var typeDisplayRepresentation: TypeDisplayRepresentation {
        TypeDisplayRepresentation(
            name: LocalizedStringResource("Archive Format", table: "AppIntents"),
            numericFormat: LocalizedStringResource("\(placeholder: .int) archive formats", table: "AppIntents")
        )
    }

    static let caseDisplayRepresentations: [IntentArchiveFormat: DisplayRepresentation] = [
        .tar: DisplayRepresentation(title: "Tar archive", subtitle: "A tar archive in the PAX Restricted format"),
        .targz: DisplayRepresentation(title: "Tar archive (gzip)", subtitle: "A tar archive in the PAX Restricted format, compressed with gzip"),
        .tarbz2: DisplayRepresentation(title: "Tar archive (bzip2)", subtitle: "A tar archive in the PAX Restricted format, compressed with bzip2"),
        .tarxz: DisplayRepresentation(title: "Tar archive (xz)", subtitle: "A tar archive in the PAX Restricted format, compressed with xz"),
        .zip: DisplayRepresentation(title: "Zip archive", subtitle: "A ZIP archive"),
        ._7z: DisplayRepresentation(title: "7-Zip archive", subtitle: "A 7-Zip archive"),
        .iso: DisplayRepresentation(title: "ISO image", subtitle: "An ISO image file"),
        .cpio: DisplayRepresentation(title: "CPIO archive", subtitle: "A CPIO archive"),
        .xar: DisplayRepresentation(title: "Xar archive", subtitle: "A Xar archive"),
    ]

    var arkyveFormat: ArkyveFormats {
        switch self {
        case .tar: return .tar
        case .targz: return .targz
        case .tarbz2: return .tarbz2
        case .tarxz: return .tarxz
        case .zip: return .zip
        case ._7z: return ._7z
        case .iso: return .iso
        case .cpio: return .cpio
        case .xar: return .xar
        }
    }
}
