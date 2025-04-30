//
//  LogWindowView.swift
//  Arkyve
//
//  Created by Chris Jones on 21/06/2024.
//

import SwiftUI
import os

struct LogWindowView: View {
    @State private var logs = ArkyveLog.shared
    @AppStorage("minimumLogLevel") private var minimumLogLevel: ArkyveLogType = .Info

    var body: some View {
        HStack {
            Picker("Minimum level", selection: $minimumLogLevel) {
                ForEach(ArkyveLogType.allCases) { option in
                    Text(option.asString)
                }
            }
            Spacer()
            Button("Clear") {
                ArkyveLog.shared.clear()
            }
        }
        .padding()
        Table(of: ArkyveLogEntry.self) {
            TableColumn("Level", value: \.levelString)
                .width(100)
            TableColumn("Message", value: \.msg)
        } rows: {
            ForEach(logs.entries.filter { $0.logType.rawValue >= minimumLogLevel.rawValue }) {
                TableRow($0)
            }
        }
    }
}

#Preview {
    LogWindowView()
}
