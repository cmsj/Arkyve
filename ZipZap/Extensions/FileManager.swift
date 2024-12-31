//
//  FileManager.swift
//  ZipZap
//
//  Created by Chris Jones on 31/12/2024.
//


extension FileManager {
    func createSymbolicLink(atPath path: String, withDestinationPath destPath: String, overwrite: Bool) throws {
        if !overwrite {
            // Easy path
            try self.createSymbolicLink(atPath: path, withDestinationPath: destPath)
        }

        if symlink(destPath, path) == -1 {
            if errno == EEXIST {
                try self.removeItem(atPath: path)
                try self.createSymbolicLink(atPath: path, withDestinationPath: destPath)
            }
        }
    }
}