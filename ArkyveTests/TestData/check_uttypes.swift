#!/usr/bin/env swift

import UniformTypeIdentifiers

let extensions = [
    "tar",
    "tar.gz",
    "tar.bz2",
    "tar.xz",
    "tgz",
    "tbz2",
    "txz",
    "zip",
    "7z",
    "a",
    "cpio",
    "iso",
    "lha",
    "lzh",
    "webarchive",
    "xar",
    "xip",
    "pkg",
    "cab",
    "sh",
    "gz",
    "bz2",
    "xz"
]

for ext in extensions {
    let utType = UTType(tag: ext, tagClass: .filenameExtension, conformingTo: nil)?.description ?? "*** UNKNOWN ***"
    let extName = ext.padding(toLength: 10, withPad: " ", startingAt: 0)
    print("\(extName) -> \(utType)")
}
