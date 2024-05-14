//
//  ZipZapApp.swift
//  ZipZap
//
//  Created by Chris Jones on 10/05/2024.
//

import SwiftUI
import zzarchive

@main
struct ZipZapApp: App {
    var body: some Scene {
        WindowGroup {
            ContentView()
        }
        .windowToolbarStyle(.expanded)
    }
}


struct TestModel: Identifiable {
    let id = UUID()
    var num = String(Int.random(in: 5...60))
    var children: [TestModel]? = nil
//    {
//        (0..<5).map { _ in
//            TestModel()
//        }
//    }

    init(populate: Bool = true) {
        if populate {
            children = (0..<5).map { _ in
                TestModel(populate: false)
            }
        } else {
            num = "99"
        }
    }
}

struct OtherModel: Identifiable {
    let id = UUID()
    let num = 99
}

struct TestView: View {
    @State var root: TestModel = .init()
    var body: some View {
        Table(of: TestModel.self) {
            TableColumn("ID", value: \.id.uuidString)
            TableColumn("Num", value: \.num)
        } rows: {
            OutlineGroup(root, children: \.children) { row in
                TableRow(row)
            }
            TableRow(TestModel(populate: false))
        }
    }
}
