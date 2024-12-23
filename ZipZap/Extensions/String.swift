//
//  String.swift
//  ZipZap
//
//  Created by Chris Jones on 04/06/2024.
//

import Foundation

extension String {
    func countOccurrences(of char: Character) -> Int {
        self.ranges(of: String(char)).count
    }

    func deletingPrefix(_ prefix: String) -> String {
        guard self.hasPrefix(prefix) else { return self }
        return String(self.dropFirst(prefix.count))
    }
}
