//
//  ArkyveLog.swift
//  Arkyve
//
//  Created by Chris Jones on 21/06/2024.
//

import Foundation
import Synchronization
import os

enum ArkyveLogType: Int, CaseIterable, Identifiable {
    case Trace = 0
    case Info
    case Warning
    case Error

    var id: Self { self }
    var asString: String {
        switch (self) {
        case .Trace:
            return "Debug"
        case .Info:
            return "Info"
        case .Warning:
            return "Warning"
        case .Error:
            return "Error"
        }
    }
    var osLogType: OSLogType {
        switch (self) {
        case .Trace:
                .debug
        case .Error:
                .error
        case .Warning:
                .error
        case .Info:
                .info
        }
    }
}

struct ArkyveLogEntry: Identifiable, Equatable, Hashable {
    let id = UUID()
    let logType: ArkyveLogType
    let msg: String

    var levelString: String {
        get {
            return self.logType.asString
        }
    }
}

extension Logger {
    /// Using your bundle identifier is a great way to ensure a unique identifier.
    private static let subsystem = Bundle.main.bundleIdentifier!

    /// Logs for Arkyve
    static let arkyve = Logger(subsystem: subsystem, category: "ArkyveLog")
}

@Observable
@MainActor
final class ArkyveLog: Sendable {
    static let shared = ArkyveLog()

    var entries: [ArkyveLogEntry] = []

    func log(_ level: ArkyveLogType, _ msg: String) {
        entries.append(ArkyveLogEntry(logType: level, msg: msg))
        if entries.count > 100 {
            entries.removeFirst()
        }
    }

    func clear() {
        entries.removeAll()
    }
}

func AKLog(_ level: ArkyveLogType, _ msg: String) {
    Task { @MainActor in
        ArkyveLog.shared.log(level, msg)
    }
}

func AKInfo(_ msg: String) {
    Logger.arkyve.info("\(msg)")
    AKLog(.Info, msg)
}

func AKWarning(_ msg: String) {
    Logger.arkyve.warning("\(msg)")
    AKLog(.Warning, msg)
}

func AKError(_ msg: String) {
    Logger.arkyve.error("\(msg)")
    AKLog(.Error, msg)
}

func AKTrace(_ msg: String) {
    Logger.arkyve.debug("\(msg)")
    AKLog(.Trace, msg)
}
