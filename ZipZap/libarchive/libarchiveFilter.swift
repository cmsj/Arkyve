//
//  libarchiveFilter.swift
//  ZipZap
//
//  Created by Chris Jones on 03/10/2024.
//

enum libarchiveFilter: Int32 {
    case None = 0
    case GZip
    case BZip2
    case Compress
    case Program
    case LZMA
    case XZ
    case UU
    case RPM
    case LZIP
    case LRZIP
    case LZOP
    case GRZIP
    case LZ4
    case ZSTD
}

extension libarchiveFilter: CustomStringConvertible {
    var description: String {
        get {
            switch (self) {
            case .None: return "None"
            case .GZip: return "GZip"
            case .BZip2: return "BZip2"
            case .Compress: return "Compress"
            case .Program: return "Program"
            case .LZMA: return "LZMA"
            case .XZ: return "XZ"
            case .UU: return "UU"
            case .RPM: return "RPM"
            case .LZIP: return "LZIP"
            case .LRZIP: return "LRZIP"
            case .LZOP: return "LZOP"
            case .GRZIP: return "GRZIP"
            case .LZ4: return "LZ4"
            case .ZSTD: return "ZSTD"
            }
        }
    }
}
