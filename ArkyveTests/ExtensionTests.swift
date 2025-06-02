//
//  ExtensionTests.swift
//  ExtensionTests
//
//  Created by Chris Jones on 24/12/2024.
//

import Testing
import Foundation
import UniformTypeIdentifiers

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

        @Test func incrementTrailingInteger() async throws {
            var name = "test1"

            #expect(name.incrementTrailingInteger() == false)
            #expect(name == "test1")

            name.filenameMustDuplicate()
            #expect(name == "test1 copy")

            name.filenameMustDuplicate()
            #expect(name == "test1 copy 2")

            name.filenameMustDuplicate()
            #expect(name == "test1 copy 3")

        }
    }

    @Suite("Date Extensions") struct DateTests {
        @Test func sinceEpochInterval() async throws {
            #expect(Date(since: 0).timeIntervalSince1970 == 0)
        }

        @Test func userFormatted() async throws {
            #expect(Date(since: 0).finderFormatted == "--")

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
            #expect(Date(since: 1).finderFormatted == expectedString)
        }

        @Test func screenshotFormatted() async throws {
            let expectedString: String

            // HACK: Depending on where the test is run, the output here will be different
            // (because DateFormatter() is used in this codepath and it cares about timezones)
            print("Adjusting expected result for: \(TimeZone.current.identifier)")
            switch TimeZone.current.identifier {
            case "Europe/London":
                expectedString = "Screenshot 1970-01-01 at 01.00.00"
            case "US/Pacific":
                expectedString = "Screenshot 1969-12-31 at 16.00.00"
            default:
                expectedString = "Unknown"
            }

            #expect(Date(since: 0).screenshotFormatted == expectedString)
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

        @Test func testBits() async throws {
            var mode: mode_t = 0

            #expect(mode.accessibilityString == "User: no read, no write, no execute, no SetUID. Group: no read, no write, no execute, no SetGID. Other: no read, no write, no execute, no sticky")

            #expect(mode.IRUSR == false)
            mode.IRUSR = true
            #expect(mode.IRUSR == true)
            mode.IRUSR = false
            #expect(mode.IRUSR == false)

            #expect(mode.IWUSR == false)
            mode.IWUSR = true
            #expect(mode.IWUSR == true)
            mode.IWUSR = false
            #expect(mode.IWUSR == false)

            #expect(mode.IXUSR == false)
            mode.IXUSR = true
            #expect(mode.IXUSR == true)
            mode.IXUSR = false
            #expect(mode.IXUSR == false)

            #expect(mode.IRGRP == false)
            mode.IRGRP = true
            #expect(mode.IRGRP == true)
            mode.IRGRP = false
            #expect(mode.IRGRP == false)

            #expect(mode.IWGRP == false)
            mode.IWGRP = true
            #expect(mode.IWGRP == true)
            mode.IWGRP = false
            #expect(mode.IWGRP == false)

            #expect(mode.IXGRP == false)
            mode.IXGRP = true
            #expect(mode.IXGRP == true)
            mode.IXGRP = false
            #expect(mode.IXGRP == false)

            #expect(mode.IROTH == false)
            mode.IROTH = true
            #expect(mode.IROTH == true)
            mode.IROTH = false
            #expect(mode.IROTH == false)

            #expect(mode.IWOTH == false)
            mode.IWOTH = true
            #expect(mode.IWOTH == true)
            mode.IWOTH = false
            #expect(mode.IWOTH == false)

            #expect(mode.IXOTH == false)
            mode.IXOTH = true
            #expect(mode.IXOTH == true)
            mode.IXOTH = false
            #expect(mode.IXOTH == false)

            #expect(mode.ISUSR == false)
            mode.ISUSR = true
            #expect(mode.ISUSR == true)
            mode.ISUSR = false
            #expect(mode.ISUSR == false)

            #expect(mode.ISGRP == false)
            mode.ISGRP = true
            #expect(mode.ISGRP == true)
            mode.ISGRP = false
            #expect(mode.ISGRP == false)

            #expect(mode.ISVTX == false)
            mode.ISVTX = true
            #expect(mode.ISVTX == true)
            mode.ISVTX = false
            #expect(mode.ISVTX == false)

            mode.IRUSR = true
            mode.IWUSR = true
            mode.IXUSR = true
            mode.IRGRP = true
            mode.IWGRP = true
            mode.IXGRP = true
            mode.IROTH = true
            mode.IWOTH = true
            mode.IXOTH = true
            mode.ISUSR = true
            mode.ISGRP = true
            mode.ISVTX = true

            #expect(mode.accessibilityString == "User: read,  write,  execute, SetUID. Group: read,  write,  execute, SetGID. Other: read,  write,  execute, sticky")
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

    @Suite("dev_t Extensions") struct DevTTests {
        @Test func testDev_t() async throws {
            var foo: dev_t = 0
            #expect(foo.major() == 0)
            #expect(foo.minor() == 0)
            #expect(foo.description == "0, 0")

            foo = 0x12345678
            #expect(foo.description == "12, 345678")

            foo = Int32.max
            #expect(foo.description == "7f, ffffff")
        }
    }

    @Suite("UTType Extensions") struct UTTypeTests {
        @Test func ensureUTTypes() async throws {
            // Types we export
            #expect(UTType.archiveEntryExtractable.isDeclared)
            #expect(UTType.archiveEntryExtractable.identifier == "net.tenshu.Arkyve.ArchiveEntryExtractable")
            #expect(UTType.ar.isDeclared)
            #expect(UTType.ar.identifier == "net.tenshu.Arkyve.ar")
            #expect(UTType.lha.isDeclared)
            #expect(UTType.lha.identifier == "net.tenshu.Arkyve.lha")
            #expect(UTType.lzh.isDeclared)
            #expect(UTType.lzh.identifier == "net.tenshu.Arkyve.lzh")

            // Types we import
            #expect(UTType.rar.isDeclared)
            #expect(UTType.cab.isDeclared)
            #expect(UTType.targz.isDeclared)
            #expect(UTType.tarxz.isDeclared)
            #expect(UTType.xz.isDeclared)
            #expect(UTType._7z.isDeclared)

            // Public types we import
            #expect(UTType.tarbz2.isDeclared)
            #expect(UTType.iso.isDeclared)
            #expect(UTType.cpio.isDeclared)

            // Apple types we import
            #expect(UTType.xar.isDeclared)
            #expect(UTType.xip.isDeclared)
            #expect(UTType.pkg.isDeclared)
        }
    }

    @Suite("Int Extensions") struct IntTests {
        @Test func human() async throws {
            var testInt = -1
            #expect(testInt.human == "--")

            testInt = 0
            #expect(testInt.human == "0 bytes")

            testInt = 1
            #expect(testInt.human == "1 bytes")

            testInt = 1023
            #expect(testInt.human == "1023 bytes")

            testInt = 1024
            #expect(testInt.human == "1 KB")

            testInt = testInt * 1024
            #expect(testInt.human == "1 MB")

            testInt = testInt * 1024
            #expect(testInt.human == "1 GB")

            testInt = testInt * 1024
            #expect(testInt.human == "1 TB")

            testInt = testInt * 1024
            #expect(testInt.human == "1 PB")

            testInt = testInt * 1024
            #expect(testInt.human == "1 EB")
        }
    }
}
