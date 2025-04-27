//
//  UTType.swift
//  Arkyve
//
//  Created by Chris Jones on 27/04/2025.
//

import UniformTypeIdentifiers

extension UTType {
    static var targz: UTType { UTType(exportedAs: "net.tenshu.Arkyve.targz") }
    static var tarbz2: UTType { UTType(exportedAs: "net.tenshu.Arkyve.tarbz2") }
    static var ar: UTType { UTType(exportedAs: "net.tenshu.Arkyve.ar") }
    static var lha: UTType { UTType(exportedAs: "net.tenshu.Arkyve.lha") }
    static var lzh: UTType { UTType(exportedAs: "net.tenshu.Arkyve.lzh") }
    static var rar: UTType { UTType(importedAs: "com.rarlab.rar-archive") }
    static var cab: UTType { UTType(importedAs: "com.microsoft.cab") }
}
