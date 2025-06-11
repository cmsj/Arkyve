//
//  ArkyveErrorTests.swift
//  ArkyveTests
//
//  Created by Chris Jones on 30/05/2025.
//

import Testing
@testable import Arkyve // Assuming your module is named Arkyve

struct ArkyveErrorTests {

    @Test func testErrorProperties() async throws {
        var error = ArkyveError(.openArchive, msg: "Testing Message")
        #expect(error.kind == .openArchive)
        #expect(error.msg == "Testing Message")
        #expect(error.description == "Open: Testing Message")
        #expect(error.description == error.localizedDescription)

        error = ArkyveError(.cancelled, msg: "")
        #expect(error.kind == .cancelled)
        #expect(error.msg == "User cancelled operation.")
    }

}
