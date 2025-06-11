import Testing
import Foundation
import UniformTypeIdentifiers
@testable import Arkyve

@Suite("ArkyveFormats Tests")
final class ArkyveFormatsTests {
    @Test func testFormatOrder() {
        // Test that formats are ordered as expected (this affects NSSavePanel display order)
        let formats = ArkyveFormats.allCases
        #expect(formats[0] == .zip)
        #expect(formats[1] == ._7z)
        #expect(formats[2] == .iso)
        #expect(formats[3] == .targz)
        #expect(formats[4] == .tarbz2)
        #expect(formats[5] == .tarxz)
        #expect(formats[6] == .tar)
    }

    @Test func testDescriptions() {
        // Test that all formats have appropriate descriptions
        #expect(ArkyveFormats.zip.description == "Zip Archive")
        #expect(ArkyveFormats._7z.description == "7Zip Archive")
        #expect(ArkyveFormats.iso.description == "ISO Image")
        #expect(ArkyveFormats.targz.description == "tar Archive (GZip)")
        #expect(ArkyveFormats.tarbz2.description == "tar Archive (BZip2)")
        #expect(ArkyveFormats.tarxz.description == "tar Archive (xz)")
        #expect(ArkyveFormats.tar.description == "tar Archive")
        #expect(ArkyveFormats.cpio.description == "CPIO Archive")
        #expect(ArkyveFormats.warc.description == "Web Archive")
        #expect(ArkyveFormats.xar.description == "eXtensible Archive")
        #expect(ArkyveFormats.xip.description == "Secure Archive")
        #expect(ArkyveFormats.pkg.description == "Installer Package")
        #expect(ArkyveFormats.cab.description == "Cabinet Archive")
        #expect(ArkyveFormats.shar.description == "Shell Archive")
        #expect(ArkyveFormats.ar.description == "Library Archive")
        #expect(ArkyveFormats.lha.description == "LHA Archive")
        #expect(ArkyveFormats.lzh.description == "LZH Archive")
        #expect(ArkyveFormats.rar.description == "RAR Archive")
        #expect(ArkyveFormats.gz.description == "GZip Archive")
        #expect(ArkyveFormats.bz2.description == "BZip2 Archive")
        #expect(ArkyveFormats.xz.description == "XZ Archive")
        #expect(ArkyveFormats.raw.description == "Raw File")
    }

    @Test func testExtensions() {
        // Test that all formats have correct file extensions
        #expect(ArkyveFormats.zip.ext == "zip")
        #expect(ArkyveFormats._7z.ext == "7z")
        #expect(ArkyveFormats.iso.ext == "iso")
        #expect(ArkyveFormats.targz.ext == "tgz")
        #expect(ArkyveFormats.tarbz2.ext == "tbz2")
        #expect(ArkyveFormats.tarxz.ext == "txz")
        #expect(ArkyveFormats.tar.ext == "tar")
        #expect(ArkyveFormats.cpio.ext == "cpio")
        #expect(ArkyveFormats.warc.ext == "webarchive")
        #expect(ArkyveFormats.xar.ext == "xar")
        #expect(ArkyveFormats.xip.ext == "xip")
        #expect(ArkyveFormats.pkg.ext == "pkg")
        #expect(ArkyveFormats.cab.ext == "cab")
        #expect(ArkyveFormats.shar.ext == "sh")
        #expect(ArkyveFormats.ar.ext == "a")
        #expect(ArkyveFormats.lha.ext == "lha")
        #expect(ArkyveFormats.lzh.ext == "lzh")
        #expect(ArkyveFormats.rar.ext == "rar")
        #expect(ArkyveFormats.gz.ext == "gz")
        #expect(ArkyveFormats.bz2.ext == "bz2")
        #expect(ArkyveFormats.xz.ext == "xz")
        #expect(ArkyveFormats.raw.ext == "")
    }

    @Test func testCanWrite() {
        // Test that only supported formats are marked as writable
        #expect(ArkyveFormats.zip.canWrite)
        #expect(ArkyveFormats._7z.canWrite)
        #expect(ArkyveFormats.iso.canWrite)
        #expect(ArkyveFormats.targz.canWrite)
        #expect(ArkyveFormats.tarbz2.canWrite)
        #expect(ArkyveFormats.tarxz.canWrite)
        #expect(ArkyveFormats.tar.canWrite)
        #expect(ArkyveFormats.cpio.canWrite)
        #expect(ArkyveFormats.xar.canWrite)
        #expect(!ArkyveFormats.warc.canWrite)
        #expect(!ArkyveFormats.xip.canWrite)
        #expect(!ArkyveFormats.pkg.canWrite)
        #expect(!ArkyveFormats.cab.canWrite)
        #expect(!ArkyveFormats.shar.canWrite)
        #expect(!ArkyveFormats.ar.canWrite)
        #expect(!ArkyveFormats.lha.canWrite)
        #expect(!ArkyveFormats.lzh.canWrite)
        #expect(!ArkyveFormats.rar.canWrite)
        #expect(!ArkyveFormats.gz.canWrite)
        #expect(!ArkyveFormats.bz2.canWrite)
        #expect(!ArkyveFormats.xz.canWrite)
        #expect(!ArkyveFormats.raw.canWrite)
    }

    @Test func testLibarchiveFormat() {
        // Test that formats map to correct libarchive formats
        #expect(ArkyveFormats.zip.libarchiveFormat == .ZIP)
        #expect(ArkyveFormats._7z.libarchiveFormat == ._7ZIP)
        #expect(ArkyveFormats.iso.libarchiveFormat == .ISO9660)
        #expect(ArkyveFormats.targz.libarchiveFormat == .TAR_PAX_RESTRICTED)
        #expect(ArkyveFormats.tarbz2.libarchiveFormat == .TAR_PAX_RESTRICTED)
        #expect(ArkyveFormats.tarxz.libarchiveFormat == .TAR_PAX_RESTRICTED)
        #expect(ArkyveFormats.tar.libarchiveFormat == .TAR_PAX_RESTRICTED)
        #expect(ArkyveFormats.cpio.libarchiveFormat == .CPIO)
        #expect(ArkyveFormats.shar.libarchiveFormat == .SHAR)
        #expect(ArkyveFormats.ar.libarchiveFormat == .AR)
        #expect(ArkyveFormats.xar.libarchiveFormat == .XAR)
        #expect(ArkyveFormats.xip.libarchiveFormat == .XAR)
        #expect(ArkyveFormats.pkg.libarchiveFormat == .XAR)
        #expect(ArkyveFormats.lha.libarchiveFormat == .LHA)
        #expect(ArkyveFormats.lzh.libarchiveFormat == .LHA)
        #expect(ArkyveFormats.cab.libarchiveFormat == .CAB)
        #expect(ArkyveFormats.rar.libarchiveFormat == .RAR)
        #expect(ArkyveFormats.warc.libarchiveFormat == .WARC)
        #expect(ArkyveFormats.gz.libarchiveFormat == .RAW)
        #expect(ArkyveFormats.bz2.libarchiveFormat == .RAW)
        #expect(ArkyveFormats.xz.libarchiveFormat == .RAW)
        #expect(ArkyveFormats.raw.libarchiveFormat == .RAW)
    }

    @Test func testLibarchiveFilters() {
        // Test that formats have correct libarchive filters
        #expect(ArkyveFormats.targz.libarchiveFilters == [.GZip])
        #expect(ArkyveFormats.gz.libarchiveFilters == [.GZip])
        #expect(ArkyveFormats.tarbz2.libarchiveFilters == [.BZip2])
        #expect(ArkyveFormats.bz2.libarchiveFilters == [.BZip2])
        #expect(ArkyveFormats.tarxz.libarchiveFilters == [.XZ])
        #expect(ArkyveFormats.xz.libarchiveFilters == [.XZ])
        #expect(ArkyveFormats.zip.libarchiveFilters == [.None])
        #expect(ArkyveFormats._7z.libarchiveFilters == [.None])
        #expect(ArkyveFormats.iso.libarchiveFilters == [.None])
        #expect(ArkyveFormats.tar.libarchiveFilters == [.None])
    }

    @Test func testUTType() {
        // Test that formats map to correct UTTypes
        #expect(ArkyveFormats.zip.utType == .zip)
        #expect(ArkyveFormats._7z.utType == ._7z)
        #expect(ArkyveFormats.iso.utType == .iso)
        #expect(ArkyveFormats.targz.utType == .targz)
        #expect(ArkyveFormats.tarbz2.utType == .tarbz2)
        #expect(ArkyveFormats.tarxz.utType == .tarxz)
        #expect(ArkyveFormats.tar.utType == .tarArchive)
        #expect(ArkyveFormats.cpio.utType == .cpio)
        #expect(ArkyveFormats.xar.utType == .xar)
        #expect(ArkyveFormats.xip.utType == .xip)
        #expect(ArkyveFormats.pkg.utType == .pkg)
        #expect(ArkyveFormats.cab.utType == .cab)
        #expect(ArkyveFormats.ar.utType == .ar)
        #expect(ArkyveFormats.lha.utType == .lha)
        #expect(ArkyveFormats.lzh.utType == .lzh)
        #expect(ArkyveFormats.rar.utType == .rar)
        #expect(ArkyveFormats.warc.utType == .webArchive)
        #expect(ArkyveFormats.gz.utType == .gzip)
        #expect(ArkyveFormats.bz2.utType == .bz2)
        #expect(ArkyveFormats.xz.utType == .xz)
        #expect(ArkyveFormats.raw.utType == nil)
    }

    @Test func testWriteableCases() {
        // Test that writeableCases returns only formats that can be written
        let writeable = ArkyveFormats.writeableCases
        #expect(writeable.contains(.zip))
        #expect(writeable.contains(._7z))
        #expect(writeable.contains(.iso))
        #expect(writeable.contains(.targz))
        #expect(writeable.contains(.tarbz2))
        #expect(writeable.contains(.tarxz))
        #expect(writeable.contains(.tar))
        #expect(writeable.contains(.cpio))
        #expect(writeable.contains(.xar))
        #expect(!writeable.contains(.warc))
        #expect(!writeable.contains(.xip))
        #expect(!writeable.contains(.pkg))
        #expect(!writeable.contains(.cab))
        #expect(!writeable.contains(.shar))
        #expect(!writeable.contains(.ar))
        #expect(!writeable.contains(.lha))
        #expect(!writeable.contains(.lzh))
        #expect(!writeable.contains(.rar))
        #expect(!writeable.contains(.gz))
        #expect(!writeable.contains(.bz2))
        #expect(!writeable.contains(.xz))
        #expect(!writeable.contains(.raw))
    }

    @Test func testInitFromlibarchiveFormatForSaving() {
        // Test initialization from libarchive format for saving
        #expect(ArkyveFormats.initFromlibarchiveFormatForSaving(.ZIP) == .zip)
        #expect(ArkyveFormats.initFromlibarchiveFormatForSaving(._7ZIP) == ._7z)
        #expect(ArkyveFormats.initFromlibarchiveFormatForSaving(.ISO9660) == .iso)
        #expect(ArkyveFormats.initFromlibarchiveFormatForSaving(.CPIO) == .cpio)
        #expect(ArkyveFormats.initFromlibarchiveFormatForSaving(.XAR) == .xar)
        #expect(ArkyveFormats.initFromlibarchiveFormatForSaving(.TAR_PAX_RESTRICTED) == .tar)
        #expect(ArkyveFormats.initFromlibarchiveFormatForSaving(.TAR_PAX_RESTRICTED, withFilters: [.GZip]) == .targz)
        #expect(ArkyveFormats.initFromlibarchiveFormatForSaving(.TAR_PAX_RESTRICTED, withFilters: [.BZip2]) == .tarbz2)
        #expect(ArkyveFormats.initFromlibarchiveFormatForSaving(.TAR_PAX_RESTRICTED, withFilters: [.XZ]) == .tarxz)
    }

    @Test func testInitFromUTType() {
        // Test initialization from UTType
        #expect(ArkyveFormats.initFromUTType(.zip) == .zip)
        #expect(ArkyveFormats.initFromUTType(._7z) == ._7z)
        #expect(ArkyveFormats.initFromUTType(.iso) == .iso)
        #expect(ArkyveFormats.initFromUTType(.targz) == .targz)
        #expect(ArkyveFormats.initFromUTType(.tarbz2) == .tarbz2)
        #expect(ArkyveFormats.initFromUTType(.tarxz) == .tarxz)
        #expect(ArkyveFormats.initFromUTType(.tarArchive) == .tar)
        #expect(ArkyveFormats.initFromUTType(.cpio) == .cpio)
        #expect(ArkyveFormats.initFromUTType(.xar) == .xar)
        #expect(ArkyveFormats.initFromUTType(.xip) == .xip)
        #expect(ArkyveFormats.initFromUTType(.pkg) == .pkg)
        #expect(ArkyveFormats.initFromUTType(.cab) == .cab)
        #expect(ArkyveFormats.initFromUTType(.ar) == .ar)
        #expect(ArkyveFormats.initFromUTType(.lha) == .lha)
        #expect(ArkyveFormats.initFromUTType(.lzh) == .lzh)
        #expect(ArkyveFormats.initFromUTType(.rar) == .rar)
        #expect(ArkyveFormats.initFromUTType(.webArchive) == nil)
        #expect(ArkyveFormats.initFromUTType(.gzip) == nil)
        #expect(ArkyveFormats.initFromUTType(.bz2) == nil)
        #expect(ArkyveFormats.initFromUTType(.xz) == nil)
        #expect(ArkyveFormats.initFromUTType(nil) == nil)
    }
} 