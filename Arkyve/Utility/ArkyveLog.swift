//
//  ArkyveLog.swift
//  Arkyve
//
//  Created by Chris Jones on 21/06/2024.
//

import Foundation
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
class ArkyveLog {
    static let shared = ArkyveLog()

    var entries: [ArkyveLogEntry] = []
    let logger = Logger(subsystem: Bundle.main.bundleIdentifier!, category: "ArkyveLog")

    private init() {}

    func log(_ level: ArkyveLogType, _ msg: String) {
        entries.append(ArkyveLogEntry(logType: level, msg: msg))
        if entries.count > 100 {
            entries.removeFirst()
        }
    }

    func clear() {
        entries.removeAll()
    }

    func info(_ msg: String) {
        log(.Info, msg)
        logger.info("\(msg)")
    }
    func warning(_ msg: String) {
        log(.Warning, msg)
        logger.warning("\(msg)")
    }
    func error(_ msg: String) {
        log(.Error, msg)
        logger.error("\(msg)")
    }
    func trace(_ msg: String) {
        log(.Trace, msg)
        logger.trace("\(msg)")
    }
}
