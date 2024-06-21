//
//  LogWindowView.swift
//  ZipZap
//
//  Created by Chris Jones on 21/06/2024.
//

import SwiftUI

struct LogWindowView: View {
    @State private var logs = ZipZapLog.shared
    @State private var minimumLevel: ZipZapLogType = .Info

    var body: some View {
        HStack {
            Picker("Minimum level", selection: $minimumLevel) {
                ForEach(ZipZapLogType.allCases) { option in
                    Text(option.asString)
                }
            }
            Spacer()
            Button("Clear") {
                logs.entries.removeAll()
            }
        }
        .padding()
        Table(of: ZipZapLogEntry.self) {
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
