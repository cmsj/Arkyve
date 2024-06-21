//
//  ZipZapLog.swift
//  ZipZap
//
//  Created by Chris Jones on 21/06/2024.
//

import Foundation
import os

enum ZipZapLogType: Int, CaseIterable, Identifiable {
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

struct ZipZapLogEntry: Identifiable {
    let id = UUID()
    let logType: ZipZapLogType
    let msg: String

    var levelString: String {
        get {
            return self.logType.asString
        }
    }
}

@Observable
@MainActor
class ZipZapLog {
    static let shared = ZipZapLog()

    var entries: [ZipZapLogEntry] = []
    let logger = Logger(subsystem: Bundle.main.bundleIdentifier!, category: "ZipZapLog")

    private init() {}

    func log(_ level: ZipZapLogType, _ msg: String) {
        entries.append(ZipZapLogEntry(logType: level, msg: msg))
        if entries.count > 100 {
            entries.removeFirst()
        }
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
