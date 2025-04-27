//
//  UTType.swift
//  Arkyve
//
//  Created by Chris Jones on 27/04/2025.
//

import UniformTypeIdentifiers

extension UTType {

    static var ar:      UTType { UTType(exportedAs: "net.tenshu.Arkyve.ar") }
    static var lha:     UTType { UTType(exportedAs: "net.tenshu.Arkyve.lha") }
    static var lzh:     UTType { UTType(exportedAs: "net.tenshu.Arkyve.lzh") }

    static var rar:     UTType { UTType(importedAs: "com.rarlab.rar-archive") }
    static var cab:     UTType { UTType(importedAs: "com.microsoft.cab") }
    static var targz:   UTType { UTType(importedAs: "org.gnu.gnu-zip-tar-archive") }
    static var _7z:     UTType { UTType(importedAs: "org.7-zip.7-zip-archive") }

    static var tarbz2:  UTType { UTType(importedAs: "public.tar-bzip2-archive") }
    static var iso:     UTType { UTType(importedAs: "public.iso-image") }
    static var cpio:    UTType { UTType(importedAs: "public.cpio-archive") }

    static var xar:     UTType { UTType(importedAs: "com.apple.xar-archive") }
    static var xip:     UTType { UTType(importedAs: "com.apple.xip-archive") }
    static var pkg:     UTType { UTType(importedAs: "com.apple.installer-package-archive") }
}
