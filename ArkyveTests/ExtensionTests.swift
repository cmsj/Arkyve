//
//  ExtensionTests.swift
//  ExtensionTests
//
//  Created by Chris Jones on 24/12/2024.
//

import Testing
import Foundation

@Suite("Extensions") struct ExtensionTests {
    @Suite("String Extensions") struct StringTests {
        @Test func countOccurences() async throws {
            // Write your test here and use APIs like `#expect(...)` to check expected conditions.
            let testString = "123123123123"
            #expect(testString.countOccurrences(of: "1") == 4)
        }

        @Test func deletingPrefix() async throws {
            let testString = "/1/2/3/4"
            #expect(testString.deletingPrefix("/1/2") == "/3/4")
            #expect(testString.deletingPrefix("nonsense") == testString)
        }

        @Test func deletingPathExtension() async throws {
            #expect("test.txt".deletingPathExtension == "test")
            #expect("archive.tar.gz".deletingPathExtension == "archive.tar")
            #expect("noextension".deletingPathExtension == "noextension")
            #expect(".hidden".deletingPathExtension == ".hidden")
        }
    }

    @Suite("Date Extensions") struct DateTests {
        @Test func sinceEpochInterval() async throws {
            #expect(Date(since: 0).timeIntervalSince1970 == 0)
        }

        @Test func userFormatted() async throws {
            #expect(Date(since: 0).userFormatted == "--")

            let expectedString: String

            // HACK: Depending on where the test is run, the output here will be different
            // (because DateFormatter() is used in this codepath and it cares about timezones)
            print("Adjusting expected result for: \(TimeZone.current.identifier)")
            switch TimeZone.current.identifier {
            case "Europe/London":
                expectedString = "1 Jan 1970 at 01:00"
            case "US/Pacific":
                expectedString = "31 Dec 1969 at 16:00"
            default:
                expectedString = "Unknown"
            }
            #expect(Date(since: 1).userFormatted == expectedString)
        }
    }

    @Suite("Array Extensions") struct ArrayTests {
        @Test func filterBothwiseSplit() async throws {
            #expect([1,2,3,4].filterBothwise { $0.isMultiple(of: 2) } == ([2,4], [1,3]))
        }

        @Test func filterBothwiseEmpty() async throws {
            let emptyArray: [Int] = []
            let (inc, exc) = emptyArray.filterBothwise { $0 > 0 }

            #expect(inc.isEmpty)
            #expect(exc.isEmpty)
        }

        @Test func remove() async throws {
            var testArray = [1,2,3,4]
            let result = testArray.remove { $0.isMultiple(of: 2) }

            #expect(result == true)
            #expect(testArray == [1,3])
        }

        @Test func subtractPathHappy() async throws {
            let path = ["user", "documents", "files"]
            let result = path.subtractPath(["user", "documents"])

            #expect(result == ["files"])
        }

        @Test func subtractPathSad() async throws {
            let path: [String] = []
            let result = path.subtractPath(["test1"])

            #expect(result == nil)

            let otherPath = ["test1", "test2"]
            let otherResult = otherPath.subtractPath(["test3"])

            #expect(otherResult == nil)
        }
    }

    @Suite("Data Extensions") struct DataTests {
        @Test func bytesEmpty() async throws {
            let data = Data()
            #expect(data.isEmpty)
            #expect(data.bytes.isEmpty)
        }

        @Test func bytesIntegrity() async throws {
            let data = Data([1,2,3,4])
            #expect(data.bytes == [UInt8]([1,2,3,4]))
        }

        @Test func bytesString() async throws {
            let string = "Hello"
            #expect(Data(string.utf8).bytes == [UInt8](string.utf8))
        }
    }

    @Suite("mode_t Extensions") struct ModeTTests {
        static let modeStringPairs: [mode_t: String] = [
            0o000000: "?---------",
            S_IFDIR:  "d---------",
            S_IFCHR:  "c---------",
            S_IFBLK:  "b---------",
            S_IFREG:  "----------",
            S_IFSOCK: "s---------",
            S_IFLNK:  "l---------",
            S_IFIFO:  "p---------",
            S_IRUSR|S_IRGRP|S_IROTH:  "?r--r--r--",
            S_IWUSR|S_IWGRP|S_IWOTH:  "?-w--w--w-",
            S_IXUSR|S_IXGRP|S_IXOTH:  "?--x--x--x",
            S_ISUID|S_ISGID|S_ISVTX:  "?--S--S--S",
            S_IXUSR|S_ISUID|S_IXGRP|S_ISGID|S_IXOTH|S_ISVTX: "?--s--s--s",
            S_IRUSR|S_IRGRP|S_IROTH|S_IWUSR|S_IWGRP|S_IWOTH|S_IXUSR|S_IXGRP|S_IXOTH: "?rwxrwxrwx",
        ]

        @Test(arguments: modeStringPairs)
        func testModeStringPairs(_ mode: mode_t, _ expectedString: String) async throws {
            #expect(mode.string == expectedString)
        }

        @Test func testDirectoryMode() async throws {
            let mode = mode_t.directory
            #expect((mode & S_IFMT) == S_IFDIR)

            #expect((mode & S_IRUSR) != 0)
            #expect((mode & S_IWUSR) != 0)
            #expect((mode & S_IXUSR) != 0)

            #expect((mode & S_IRGRP) != 0)
            #expect((mode & S_IWGRP) != 0)
            #expect((mode & S_IXGRP) != 0)

            #expect((mode & S_IROTH) != 0)
            #expect((mode & S_IWOTH) == 0)
            #expect((mode & S_IXOTH) != 0)
        }
    }

    @Suite("FileManager Extensions") struct FileManagerTests {
        @Test func createSymbolicLinkSuccess() async throws {
            let fm = FileManager.default
            let tempDir = fm.temporaryDirectory
            let sourcePath = tempDir.appendingPathComponent("source1.txt").path
            let destPath = tempDir.appendingPathComponent("dest1.txt").path

            do {
                try fm.removeItem(atPath: sourcePath)
                try fm.removeItem(atPath: destPath)
            } catch {}

            // Create a source file
            try "test content".write(toFile: sourcePath, atomically: true, encoding: .utf8)
            
            // Create the symbolic link
            do {
                try fm.createSymbolicLink(atPath: destPath, withDestinationPath: sourcePath, overwrite: false)
            } catch {
                #expect(Bool(false), "Failed to create symbolic link: \(error)")
            }

            // Verify the link exists and points to the correct destination
            let attributes = try fm.attributesOfItem(atPath: destPath)
            #expect(attributes[.type] as? FileAttributeType == .typeSymbolicLink)
            
            // Cleanup
            try fm.removeItem(atPath: sourcePath)
            try fm.removeItem(atPath: destPath)
        }
        
        @Test func createSymbolicLinkOverwrite() async throws {
            let fm = FileManager.default
            let tempDir = fm.temporaryDirectory
            let sourcePath = tempDir.appendingPathComponent("source2.txt").path
            let destPath = tempDir.appendingPathComponent("dest2.txt").path

            do {
                try fm.removeItem(atPath: sourcePath)
                try fm.removeItem(atPath: destPath)
            } catch {}

            // Create initial source and destination files
            try "test content".write(toFile: sourcePath, atomically: true, encoding: .utf8)
            try "old content".write(toFile: destPath, atomically: true, encoding: .utf8)
            
            // Create the symbolic link with overwrite
            try fm.createSymbolicLink(atPath: destPath, withDestinationPath: sourcePath, overwrite: true)
            
            // Verify the link exists and points to the correct destination
            let attributes = try fm.attributesOfItem(atPath: destPath)
            #expect(attributes[.type] as? FileAttributeType == .typeSymbolicLink)
            
            // Cleanup
            try fm.removeItem(atPath: sourcePath)
            try fm.removeItem(atPath: destPath)
        }
        
        @Test func createSymbolicLinkDestinationNotFound() async throws {
            let fm = FileManager.default
            let tempDir = fm.temporaryDirectory
            let sourcePath = tempDir.appendingPathComponent("nonexistent.txt").path
            let destPath = tempDir.appendingPathComponent("dest3.txt").path

            do {
                try fm.removeItem(atPath: sourcePath)
                try fm.removeItem(atPath: destPath)
            } catch {}

            // Attempt to create a symbolic link to a non-existent file
            do {
                try fm.createSymbolicLink(atPath: destPath, withDestinationPath: sourcePath, overwrite: false)
                #expect(fm.fileExists(atPath: destPath) == false)
            } catch {
                #expect(true, "Error was thrown as expected")
            }
        }
    }
}
