//
//  dev_t.swift
//  Arkyve
//
//  Created by Chris Jones on 02/05/2025.
//

import Darwin

extension dev_t {
    func major(_ x: dev_t) -> Int32 {
        return (x >> 24) & 0xff
    }

    func minor(_ x: dev_t) -> Int32 {
        return x & 0xffffff
    }

    var description: String {
        let major = major(self)
        let minor = minor(self)

        return "\(major), \(minor)"
    }
}
