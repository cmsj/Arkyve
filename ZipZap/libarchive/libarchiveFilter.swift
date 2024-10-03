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