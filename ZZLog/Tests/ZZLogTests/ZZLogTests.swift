import SwiftSyntax
import SwiftSyntaxBuilder
import SwiftSyntaxMacros
import SwiftSyntaxMacrosTestSupport
import XCTest

// Macro implementations build for the host, so the corresponding module is not available when cross-compiling. Cross-compiled tests may still make use of the macro itself in end-to-end tests.
#if canImport(ZZLogMacros)
import ZZLogMacros

let testMacros: [String: Macro.Type] = [
    "ZZTrace": ZZLogTraceMacro.self,
]
#endif

final class ZZLogTests: XCTestCase {
    func testTraceMacro() throws {
        #if canImport(ZZLogMacros)
        assertMacroExpansion(
            """
            #ZZTrace("hello")
            """,
            expandedSource: """
            _ = Task {
                    await MainActor.run {
                        ArkyveLog.shared.trace("hello")
                    }
                }
            """,
            macros: testMacros
        )
        #else
        throw XCTSkip("macros are only supported when running tests for the host platform")
        #endif
    }
}
