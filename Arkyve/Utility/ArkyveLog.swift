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

struct ArkyveLogEntry: Identifiable {
    let id = UUID()
    let logType: ArkyveLogType
    let msg: String

    var levelString: String {
        get {
            return self.logType.asString
        }
    }
}

@Observable
@MainActor
final class ArkyveLog: Sendable {
    static let shared = ArkyveLog()

    @ObservationIgnored
    private let logger = Logger(subsystem: Bundle.main.bundleIdentifier!, category: "ArkyveLog")

    var entries: [ArkyveLogEntry] = []

    func log(_ level: ArkyveLogType, _ msg: String) {
        logger.log(level: level.osLogType, "\(msg)")

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
    AKLog(.Info, msg)
}
func AKWarning(_ msg: String) {
    AKLog(.Warning, msg)
}
func AKError(_ msg: String) {
    AKLog(.Error, msg)
}
func AKTrace(_ msg: String) {
    AKLog(.Trace, msg)
    }
