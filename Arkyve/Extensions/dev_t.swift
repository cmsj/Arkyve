//
//  dev_t.swift
//  Arkyve
//
//  Created by Chris Jones on 02/05/2025.
//

import Darwin

extension dev_t {
    func major() -> Int32 {
        return (self >> 24) & 0xff
    }

    func minor() -> Int32 {
        return self & 0xffffff
    }

    var description: String {
        let major = String(major(), radix: 16)
        let minor = String(minor(), radix: 16)
        return "\(major), \(minor)"
    }
}
