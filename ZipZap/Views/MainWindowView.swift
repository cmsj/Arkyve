//
//  MainWindowView.swift
//  ZipZap
//
//  Created by Chris Jones on 10/05/2024.
//

import SwiftUI

struct MainWindowView: View {
    private var viewModel = MainWindowViewModel()
    @State var windowTitle = "ZipZap"
    @State var showFileChooser = false
    @State var showLog: Bool = false

    var body: some View {
        VStack {
            TableView()
                .environment(viewModel)
            StatusbarView()
                .environment(viewModel)
        }
        .toolbar(id: "Main") {
            ToolbarContentView(viewModel: viewModel)
        }
        .navigationTitle(windowTitle)
        .frame(maxWidth: .infinity, maxHeight: .infinity)
    }
}

#Preview {
    MainWindowView()
}
