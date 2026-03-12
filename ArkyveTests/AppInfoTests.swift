import Testing
import Foundation
@testable import Arkyve

@Suite("AppInfo Tests")
final class AppInfoTests {
    let appInfo = AppInfo.shared

    @Test func testAppName() {
        #expect(appInfo.appName == "Arkyve")
    }

    @Test func testDisplayName() {
        #expect(appInfo.displayName == "(unknown app display name)")
    }

    @Test func testVersion() {
        #expect(appInfo.version == "1.4")
    }

    @Test func testBuild() {
        #expect(appInfo.build != "(unknown build number)")
    }

    @Test func testMinimumOSVersion() {
        #expect(appInfo.minimumOSVersion == "15.5")
    }

    @Test func testCopyrightNotice() {
        #expect(appInfo.copyrightNotice == "© 2025 Chris Jones. All Rights Reserved")
        #expect(appInfo.copyrightNotice.contains("©"))
    }

    @Test func testBundleIdentifier() {
        #expect(appInfo.bundleIdentifier != "(unknown bundle identifier)")
        #expect(appInfo.bundleIdentifier.contains("net.tenshu.Arkyve"))
    }

    @Test func testDeveloper() {
        #expect(appInfo.developer == "my awesome name")
    }

    @Test func testTestingDetection() {
        #expect(appInfo.isRunningUnitTests == true)
    }
}
