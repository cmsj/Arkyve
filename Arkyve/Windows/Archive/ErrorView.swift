//
//  ErrorView.swift
//  Arkyve
//
//  Created by Chris Jones on 05/06/2024.
//

import SwiftUI

struct ErrorView: View {
    @Environment(ArchiveViewModel.self) var viewModel

    var body: some View {
        HStack {
            Spacer()
            Text(viewModel.errors.error?.localizedDescription ?? "")
            Spacer()
            Image(systemName: "multiply")
                .padding([.trailing], 5)
                .onTapGesture {
                    withAnimation {
                        viewModel.errors.clear()
                    }
                }
        }
        .padding([.top, .bottom], 2)
        .background(Color(#colorLiteral(red: 0.7470226884, green: 0, blue: 0, alpha: 0.5411817071)))
        .hide(if: !viewModel.errors.show)
    }
}

#Preview {
    let settingsManager = SettingsManager.shared
    let sbm = ScopedURLManager.dropSBM
    let cacheManager = CacheManager.dropCache
    let viewModel = ArchiveViewModel(id: UUID(uuidString: "00000000-0000-0000-0000-000000000000")!, settingsManager: settingsManager, scopedURLManager: sbm, cacheManager: cacheManager)

    VStack(spacing: 0) {
        ErrorView()
            .environment(viewModel)
        Rectangle()
            .backgroundStyle(.secondary)
    }
    .task {
        try? await Task.sleep(for: .seconds(2))
        viewModel.errors.err(ArkyveError(.extract, msg: "Hello World"))
        withAnimation {
            viewModel.errors.show = true
        }
    }
}
