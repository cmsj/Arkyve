//
//  StatusbarView.swift
//  Arkyve
//
//  Created by Chris Jones on 04/06/2024.
//

import SwiftUI

struct StatusbarView: View {
    @Environment(ArchiveViewModel.self) var viewModel
    @EnvironmentObject var settingsManager: SettingsManager

    @State var showPasswordSheet: Bool = false

    var body: some View {
        @Bindable var viewModel = viewModel

        VStack {
            HStack {
                Image("custom.pencil.slash")
                    .foregroundStyle(.secondary)
                    .padding(7)
                    .padding(.leading, 2)
                    .help("This archive is read-only")
                    .popoverTip(viewModel.tips.readOnlyStatus, arrowEdge: .top)
                    .tipImageStyle(.secondary)
                    .hide(if: viewModel.format.canWrite)
                Image(systemName: viewModel.lockSymbol)
                    .foregroundStyle(.secondary)
                    .padding(7)
                    .padding(.leading, 2)
                    .help(viewModel.lockHelp)
                    .popoverTip(viewModel.tips.encryptedNonZip, arrowEdge: .top)
                    .tipImageStyle(.secondary)
                    .sheet(isPresented: $showPasswordSheet) {
                        ToggleableSecureFieldSheet(title: "Archive password:", text: $viewModel.passphraseToSave, prompt: nil)
                            .environment(viewModel)
                    }
                    .onTapGesture {
                        showPasswordSheet.toggle()
                    }
                Spacer()
                Text(viewModel.statusBarText)
                    .font(.footnote)
                    .foregroundStyle(.secondary)
                    .padding(.vertical, 5)
                Spacer()
                // This is just a neat place to hide a view that populates viewModel.window
                NSWindowAccessor(delegate: viewModel)
                    .frame(width: 0, height: 0)
#if DEBUG
                HStack {
                    Text(viewModel.passphraseAtLoad)
                    Text(viewModel.passphraseToSave)
                    Text(viewModel.diskURL?.absoluteString ?? "NO DISKURL")
                        .padding([.bottom], 5)
                    Text("UI Disabled: \(viewModel.disableUI)")
                        .padding([.bottom, .trailing], 5)
                    Text("Format: \(viewModel.format.description)")
                    Text("Filters: \(viewModel.filters.description)")
                }
                .hide(if: settingsManager.showDebugUI == false)
#endif
            }
        }
        .overlay(Rectangle().frame(width: nil, height: 0.5, alignment: .top).foregroundColor(Color.black), alignment: .top)
    }
}

//#Preview {
//    let viewModel = MainWindowViewModel()
//
//    VStack(spacing: 0) {
//        Rectangle()
//            .background(.white)
//        StatusbarView()
//            .environment(viewModel)
//    }
//    .task {
//        try? await Task.sleep(for: .seconds(5))
//        viewModel.newButton()
//    }
//}
