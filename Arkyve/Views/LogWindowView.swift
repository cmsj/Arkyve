//
//  LogWindowView.swift
//  Arkyve
//
//  Created by Chris Jones on 21/06/2024.
//

import SwiftUI

struct LogWindowView: View {
    @State private var logs = ArkyveLog.shared
    @State private var minimumLevel: ArkyveLogType = .Info

    var body: some View {
        HStack {
            Picker("Minimum level", selection: $minimumLevel) {
                ForEach(ArkyveLogType.allCases) { option in
                    Text(option.asString)
                }
            }
            Spacer()
            Button("Clear") {
                logs.clear()
            }
        }
        .padding()
        Table(of: ArkyveLogEntry.self) {
            TableColumn("Level", value: \.levelString)
                .width(100)
            TableColumn("Message", value: \.msg)
        } rows: {
            ForEach(logs.entries.filter { $0.logType.rawValue >= minimumLevel.rawValue }) {
                TableRow($0)
            }
        }
    }
}

#Preview {
    LogWindowView()
}
