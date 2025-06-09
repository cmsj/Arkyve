//
//  FileManager.swift
//  Arkyve
//
//  Created by Chris Jones on 31/12/2024.
//

import Foundation

extension FileManager {
    /// Creates a symbolic link at the specified path pointing to the destination path.
    ///
    /// This method creates a symbolic link (symlink) that points from `path` to `destPath`. If `overwrite` is true,
    /// any existing file or link at the target path will be removed before creating the new link.
    ///
    /// - Parameters:
    ///   - path: The path where the symbolic link will be created. This is the location where the link will appear
    ///     in the filesystem.
    ///   - destPath: The destination path that the symbolic link will point to. This is the target location that
    ///     the link will reference.
    ///   - overwrite: If true, any existing file or link at `path` will be removed before creating the new link.
    ///     If false, the operation will fail if a file or link already exists at `path`.
    ///
    /// - Throws: An error if:
    ///   - The symbolic link cannot be created
    ///   - A file or link already exists at `path` and `overwrite` is false
    ///   - The destination path doesn't exist
    ///   - The user doesn't have sufficient permissions
    ///
    /// - Note: This method is a convenience wrapper around the standard `createSymbolicLink` method that adds
    ///   the ability to overwrite existing links.
    func createSymbolicLink(atPath path: String, withDestinationPath destPath: String, overwrite: Bool) throws {
        // If overwrite is true and the link exists, remove it first
        if overwrite {
            try? self.removeItem(atPath: path)
        }

        // Try to create the symbolic link
        try self.createSymbolicLink(atPath: path, withDestinationPath: destPath)
    }

    /// Checks if a file or folder at the given URL exists and if it is a directory or a file.
    /// - Parameter path: The path to check.
    /// - Returns: A tuple with the first ``Bool`` representing if the path exists and the second ``Bool`` representing if the found is a directory (`true`) or not (`false`).
    func fileExistsAndIsDirectory(atPath path: String) -> (Bool, Bool) {
        var fileIsDirectory: ObjCBool = false
        let fileExists = FileManager.default.fileExists(atPath: path, isDirectory: &fileIsDirectory)
        return (fileExists, fileIsDirectory.boolValue)
    }
}
