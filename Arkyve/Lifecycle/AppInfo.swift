//
//  AppInfo.swift
//  Arkyve
//
//  Created by Chris Jones on 11/06/2025.
//

/// Wrapper to get some app related strings at one place.
struct AppInfo: Sendable {
    static let shared = AppInfo()

    /// Returns the official app name, defined in your project data.
    var appName : String {
        return readFromInfoPlist(withKey: "CFBundleName") ?? "(unknown app name)"
    }

    /// Return the official app display name, eventually defined in your 'infoplist'.
    var displayName : String {
        return readFromInfoPlist(withKey: "CFBundleDisplayName") ?? "(unknown app display name)"
    }

    /// Returns the official version, defined in your project data.
    var version : String {
        return readFromInfoPlist(withKey: "CFBundleShortVersionString") ?? "(unknown app version)"
    }

    /// Returns the official 'build', defined in your project data.
    var build : String {
        return readFromInfoPlist(withKey: "CFBundleVersion") ?? "(unknown build number)"
    }

    /// Returns the minimum OS version defined in your project data.
    var minimumOSVersion : String {
        return readFromInfoPlist(withKey: "MinimumOSVersion") ?? "(unknown minimum OSVersion)"
    }

    /// Returns the copyright notice eventually defined in your project data.
    var copyrightNotice : String {
        return readFromInfoPlist(withKey: "NSHumanReadableCopyright") ?? "(unknown copyright notice)"
    }

    /// Returns the official bundle identifier defined in your project data.
    var bundleIdentifier : String {
        return readFromInfoPlist(withKey: "CFBundleIdentifier") ?? "(unknown bundle identifier)"
    }

    var developer : String { return "my awesome name" }

    var isRunningUnitTests: Bool {
        ProcessInfo.processInfo.environment["XCTestSessionIdentifier"] != nil
    }

    // MARK: - Private stuff

    // lets hold a reference to the Info.plist of the app as Dictionary
//    private let infoPlistDictionary = Bundle.main.infoDictionary

    /// Retrieves and returns associated values (of Type String) from info.Plist of the app.
    private func readFromInfoPlist(withKey key: String) -> String? {
        return Bundle.main.infoDictionary?[key] as? String
    }
}
