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
        }
    }

    @Suite("Date Extensions") struct DateTests {
        @Test func sinceEpochInterval() async throws {
            #expect(Date(since: 0).timeIntervalSince1970 == 0)
        }

        @Test func userFormatted() async throws {
            #expect(Date(since: 0).userFormatted == "--")

            #expect(Date(since: 1).userFormatted == "1 Jan 1970 at 01:00")
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
    }
}
