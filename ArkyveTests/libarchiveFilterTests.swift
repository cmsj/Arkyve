import Testing
import Foundation
@testable import Arkyve

@Suite("libarchiveFilter Tests")
final class libarchiveFilterTests {
    @Test func testFilterValues() {
        // Test that all filter values match their expected raw values
        #expect(libarchiveFilter.None.rawValue == 0)
        #expect(libarchiveFilter.GZip.rawValue == 1)
        #expect(libarchiveFilter.BZip2.rawValue == 2)
        #expect(libarchiveFilter.Compress.rawValue == 3)
        #expect(libarchiveFilter.Program.rawValue == 4)
        #expect(libarchiveFilter.LZMA.rawValue == 5)
        #expect(libarchiveFilter.XZ.rawValue == 6)
        #expect(libarchiveFilter.UU.rawValue == 7)
        #expect(libarchiveFilter.RPM.rawValue == 8)
        #expect(libarchiveFilter.LZIP.rawValue == 9)
        #expect(libarchiveFilter.LRZIP.rawValue == 10)
        #expect(libarchiveFilter.LZOP.rawValue == 11)
        #expect(libarchiveFilter.GRZIP.rawValue == 12)
        #expect(libarchiveFilter.LZ4.rawValue == 13)
        #expect(libarchiveFilter.ZSTD.rawValue == 14)
    }

    @Test func testFilterDescriptions() {
        // Test that all filters have appropriate descriptions
        #expect(libarchiveFilter.None.description == "None")
        #expect(libarchiveFilter.GZip.description == "GZip")
        #expect(libarchiveFilter.BZip2.description == "BZip2")
        #expect(libarchiveFilter.Compress.description == "Compress")
        #expect(libarchiveFilter.Program.description == "Program")
        #expect(libarchiveFilter.LZMA.description == "LZMA")
        #expect(libarchiveFilter.XZ.description == "XZ")
        #expect(libarchiveFilter.UU.description == "UU")
        #expect(libarchiveFilter.RPM.description == "RPM")
        #expect(libarchiveFilter.LZIP.description == "LZIP")
        #expect(libarchiveFilter.LRZIP.description == "LRZIP")
        #expect(libarchiveFilter.LZOP.description == "LZOP")
        #expect(libarchiveFilter.GRZIP.description == "GRZIP")
        #expect(libarchiveFilter.LZ4.description == "LZ4")
        #expect(libarchiveFilter.ZSTD.description == "ZSTD")
    }

    @Test func testIdentifiable() {
        // Test that the Identifiable protocol is implemented correctly
        #expect(libarchiveFilter.None.id == 0)
        #expect(libarchiveFilter.GZip.id == 1)
        #expect(libarchiveFilter.BZip2.id == 2)
        #expect(libarchiveFilter.Compress.id == 3)
        #expect(libarchiveFilter.Program.id == 4)
        #expect(libarchiveFilter.LZMA.id == 5)
        #expect(libarchiveFilter.XZ.id == 6)
        #expect(libarchiveFilter.UU.id == 7)
        #expect(libarchiveFilter.RPM.id == 8)
        #expect(libarchiveFilter.LZIP.id == 9)
        #expect(libarchiveFilter.LRZIP.id == 10)
        #expect(libarchiveFilter.LZOP.id == 11)
        #expect(libarchiveFilter.GRZIP.id == 12)
        #expect(libarchiveFilter.LZ4.id == 13)
        #expect(libarchiveFilter.ZSTD.id == 14)
    }
} 
