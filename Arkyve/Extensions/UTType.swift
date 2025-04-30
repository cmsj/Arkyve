//
//  UTType.swift
//  Arkyve
//
//  Created by Chris Jones on 27/04/2025.
//

import UniformTypeIdentifiers

extension UTType {
    // We export this, but only for our internal drag & drop use
    static var archiveEntryExtractable: UTType { UTType(exportedAs: "net.tenshu.Arkyve.ArchiveEntryExtractable")}

    // Archive types we export, because they otherwise don't exist
    static var ar:      UTType { UTType(exportedAs: "net.tenshu.Arkyve.ar") }
    static var lha:     UTType { UTType(exportedAs: "net.tenshu.Arkyve.lha") }
    static var lzh:     UTType { UTType(exportedAs: "net.tenshu.Arkyve.lzh") }

    // These are all exported by Archive Utility.app which is pre-installed, so we should be fine to import them
    static var rar:     UTType { UTType(importedAs: "com.rarlab.rar-archive") }
    static var cab:     UTType { UTType(importedAs: "com.microsoft.cab") }
    static var targz:   UTType { UTType(importedAs: "org.gnu.gnu-zip-tar-archive") }
    static var tarxz:   UTType { UTType(importedAs: "org.tukaani.tar-xz-archive") }
    static var xz:      UTType { UTType(importedAs: "org.tukaani.xz-archive") }
    static var _7z:     UTType { UTType(importedAs: "org.7-zip.7-zip-archive") }

    // In theory we shouldn't need to import these, yet here we are
    static var tarbz2:  UTType { UTType(importedAs: "public.tar-bzip2-archive") }
    static var iso:     UTType { UTType(importedAs: "public.iso-image") }
    static var cpio:    UTType { UTType(importedAs: "public.cpio-archive") }

    // Ditto
    static var xar:     UTType { UTType(importedAs: "com.apple.xar-archive") }
    static var xip:     UTType { UTType(importedAs: "com.apple.xip-archive") }
    static var pkg:     UTType { UTType(importedAs: "com.apple.installer-package-archive") }
}
