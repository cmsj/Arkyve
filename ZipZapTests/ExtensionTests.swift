//
//  ExtensionTests.swift
//  ExtensionTests
//
//  Created by Chris Jones on 24/12/2024.
//

import Testing
import Foundation

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

        #expect(Date(since: 1).userFormatted == "1 January 1970 at 01:00:01 GMT+1")
    }
}

@Suite("Array Extensions") struct ArrayTests {
    @Test func filterBothwise() async throws {
        #expect([1,2,3,4].filterBothwise { $0.isMultiple(of: 2) } == ([2,4], [1,3]))
    }

    @Test func remove() async throws {
        var testArray = [1,2,3,4]
        let result = testArray.remove { $0.isMultiple(of: 2) }

        #expect(result == true)
        #expect(testArray == [1,3])
    }
}
