//
//  ArchiveEntryTests.swift
//  ZipZapTests
//
//  Created by Chris Jones on 06/03/2025.
//

import Testing
import Foundation
@testable import ZipZap // Assuming your module is named ZipZap

@Suite("ArchiveEntryTests")
struct ArchiveEntryTests {

    @Test("Initialize from libarchiveHeader")
    func testInitFromHeader() throws {
        // Arrange
        let header = libarchiveHeader(
            source: ArchiveEntrySource(type: .Archive, path: "test.txt"),
            type: .file,
            path: "folder/test.txt",
            name: "test.txt",
            pathComponents: ["folder", "test.txt"],
            size: 100,
            atime: Date(timeIntervalSince1970: 1000),
            ctime: Date(timeIntervalSince1970: 2000),
            mtime: Date(timeIntervalSince1970: 3000),
            btime: Date(timeIntervalSince1970: 4000),
            uid: 501,
            gid: 20,
            perms: 0o644
        )

        // Act
        let entry = ArchiveEntry(header)

        // Assert
        #expect(entry.source.type == .Archive)
        #expect(entry.source.path == "test.txt")
        #expect(entry.path == "folder/test.txt")
        #expect(entry.name == "test.txt")
        #expect(entry.pathComponents == ["folder", "test.txt"])
        #expect(entry.size == 100)
        #expect(entry.atime == Date(timeIntervalSince1970: 1000))
        #expect(entry.ctime == Date(timeIntervalSince1970: 2000))
        #expect(entry.mtime == Date(timeIntervalSince1970: 3000))
        #expect(entry.btime == Date(timeIntervalSince1970: 4000))
        #expect(entry.uid == 501)
        #expect(entry.gid == 20)
        #expect(entry.perms == 0o644)
        #expect(entry.type == .file)
        #expect(entry.children == nil)
    }

    @Test("Initialize synthetic directory")
    func testInitSyntheticDirectory() throws {
        // Act
        let entry = ArchiveEntry(syntheticDirectory: "folder/subfolder")

        // Assert
        #expect(entry.source.type == .Synthetic)
        #expect(entry.source.path == "folder/subfolder")
        #expect(entry.path == "folder/subfolder")
        #expect(entry.name == "subfolder")
        #expect(entry.pathComponents == ["folder", "subfolder"])
        #expect(entry.size == -1)
        #expect(entry.type == .directory)
        #expect(entry.children?.isEmpty == true)
        #expect(entry.isSynthesized == true)
    }

    @Test("Initialize root entry")
    func testInitRoot() throws {
        // Act
        let entry = ArchiveEntry(isRoot: true)

        // Assert
        #expect(entry.source.type == .Root)
        #expect(entry.source.path == ".")
        #expect(entry.path == ".")
        #expect(entry.name == "root")
        #expect(entry.pathComponents == ["."])
        #expect(entry.size == -1)
        #expect(entry.type == .root)
        #expect(entry.children?.isEmpty == true)
        #expect(entry.isSynthesized == true)
    }

    @Test("Add root items")
    func testAddRootItems() throws {
        // Arrange
        let root = ArchiveEntry(isRoot: true)
        let file1 = createFileEntry(path: "file1.txt")
        let file2 = createFileEntry(path: "file2.txt")

        // Act
        try root.addRootItems([file1, file2])

        // Assert
        #expect(root.children?.count == 2)
        #expect(root.children?[0].name == "file1.txt")
        #expect(root.children?[1].name == "file2.txt")
    }

    @Test("Add root items to non-directory throws error")
    func testAddRootItemsToNonDirectory() throws {
        // Arrange
        let file = createFileEntry(path: "file.txt")
        let item = createFileEntry(path: "item.txt")

        // Act & Assert
        #expect(throws: ArchiveError.self) {
            try file.addRootItems([item])
        }
    }

    @Test("Add child hierarchically to root")
    func testAddChildHierarchicallyToRoot() throws {
        // Arrange
        let root = ArchiveEntry(isRoot: true)
        let file = createFileEntry(path: "folder/file.txt")

        // Act
        let syntheticEntries = try root.addChildHierarchically(file)

        // Assert
        #expect(syntheticEntries.count == 1)
        #expect(syntheticEntries[0].name == "folder")
        #expect(syntheticEntries[0].isSynthesized == true)
        #expect(root.children?.count == 1)
        #expect(root.children?[0].name == "folder")
        #expect(root.children?[0].children?.count == 1)
        #expect(root.children?[0].children?[0].name == "file.txt")
    }

    @Test("Add child hierarchically to existing directory")
    func testAddChildHierarchicallyToExistingDirectory() throws {
        // Arrange
        let root = ArchiveEntry(isRoot: true)
        let folder = ArchiveEntry(syntheticDirectory: "folder")
        try root.addRootItems([folder])
        let file = createFileEntry(path: "folder/file.txt")

        // Act
        let syntheticEntries = try root.addChildHierarchically(file)

        // Assert
        #expect(syntheticEntries.isEmpty)
        #expect(root.children?.count == 1)
        #expect(root.children?[0].name == "folder")
        #expect(root.children?[0].children?.count == 1)
        #expect(root.children?[0].children?[0].name == "file.txt")
    }

    @Test("Add child hierarchically with nested path")
    func testAddChildHierarchicallyWithNestedPath() throws {
        // Arrange
        let root = ArchiveEntry(isRoot: true)
        let file = createFileEntry(path: "folder/subfolder/file.txt")

        // Act
        let syntheticEntries = try root.addChildHierarchically(file)

        // Assert
        #expect(syntheticEntries.count == 2)
        #expect(syntheticEntries[0].name == "folder")
        #expect(syntheticEntries[1].name == "subfolder")
        #expect(root.children?.count == 1)
        #expect(root.children?[0].name == "folder")
        #expect(root.children?[0].children?.count == 1)
        #expect(root.children?[0].children?[0].name == "subfolder")
        #expect(root.children?[0].children?[0].children?.count == 1)
        #expect(root.children?[0].children?[0].children?[0].name == "file.txt")
    }

    @Test("Add child hierarchically to non-directory throws error")
    func testAddChildHierarchicallyToNonDirectory() throws {
        // Arrange
        let file = createFileEntry(path: "file.txt")
        let childFile = createFileEntry(path: "child.txt")

        // Act & Assert
        #expect(throws: ArchiveError.self) {
            try file.addChildHierarchically(childFile)
        }
    }

    @Test("Add multiple children hierarchically")
    func testAddChildrenHierarchically() throws {
        // Arrange
        let root = ArchiveEntry(isRoot: true)
        let file1 = createFileEntry(path: "folder1/file1.txt")
        let file2 = createFileEntry(path: "folder1/file2.txt")
        let file3 = createFileEntry(path: "folder2/file3.txt")

        // Act
        let syntheticEntries = try root.addChildrenHierarchically([file1, file2, file3])

        // Assert
        #expect(syntheticEntries.count == 2) // folder1 and folder2
        #expect(root.children?.count == 2)

        let folder1 = root.children?.first(where: { $0.name == "folder1" })
        #expect(folder1 != nil)
        #expect(folder1?.children?.count == 2)

        let folder2 = root.children?.first(where: { $0.name == "folder2" })
        #expect(folder2 != nil)
        #expect(folder2?.children?.count == 1)
    }

    @Test("Flat children representation")
    func testFlatChildren() throws {
        // Arrange
        let root = ArchiveEntry(isRoot: true)
        let file1 = createFileEntry(path: "folder/file1.txt")
        let file2 = createFileEntry(path: "folder/file2.txt")

        _ = try root.addChildrenHierarchically([file1, file2])

        // Act
        let flatEntries = root.flatChildren()

        // Assert
        #expect(flatEntries.count == 4) // root, folder, file1, file2
        #expect(flatEntries[0].path == ".")
        #expect(flatEntries[1].path == "folder")

        // The order of file1 and file2 might vary, so check both exist
        let paths = flatEntries.map { $0.path }
        #expect(paths.contains("folder/file1.txt"))
        #expect(paths.contains("folder/file2.txt"))
    }

    @Test("Sort entries")
    func testSort() throws {
        // Arrange
        let root = ArchiveEntry(isRoot: true)
        let fileC = createFileEntry(path: "c.txt")
        let fileA = createFileEntry(path: "a.txt")
        let fileB = createFileEntry(path: "b.txt")

        try root.addRootItems([fileC, fileA, fileB])

        // Act
        root.sort(using: KeyPathComparator(\.name))

        // Assert
        #expect(root.children?.count == 3)
        #expect(root.children?[0].name == "a.txt")
        #expect(root.children?[1].name == "b.txt")
        #expect(root.children?[2].name == "c.txt")
    }

    @Test("Sort entries recursively")
    func testSortRecursively() throws {
        // Arrange
        let root = ArchiveEntry(isRoot: true)
        let fileC = createFileEntry(path: "folder/c.txt")
        let fileA = createFileEntry(path: "folder/a.txt")
        let fileB = createFileEntry(path: "folder/b.txt")

        _ = try root.addChildrenHierarchically([fileC, fileA, fileB])

        // Act
        root.sort(using: KeyPathComparator(\.name))

        // Assert
        let folder = root.children?[0]
        #expect(folder?.children?.count == 3)
        #expect(folder?.children?[0].name == "a.txt")
        #expect(folder?.children?[1].name == "b.txt")
        #expect(folder?.children?[2].name == "c.txt")
    }

    // Helper method to create file entries for testing
    private func createFileEntry(path: String) -> ArchiveEntry {
        let components = path.split(separator: "/").map(String.init)
        let name = components.last ?? ""

        let header = libarchiveHeader(
            source: ArchiveEntrySource(type: .Archive, path: path),
            type: .file,
            path: path,
            name: name,
            pathComponents: components,
            size: 100,
            atime: Date(),
            ctime: Date(),
            mtime: Date(),
            btime: Date(),
            uid: 501,
            gid: 20,
            perms: 0o644
        )

        return ArchiveEntry(header)
    }
}
