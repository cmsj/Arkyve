//
//  FormatPicker.swift
//  ZipZap
//
//  Created by Chris Jones on 16/01/2025.
//

import SwiftUI

struct FormatPicker: View {
    @Environment(\.formatPickerViewModel) var viewModel: FormatPickerViewModel
    private var filteredFormats: [libarchiveFormat] = [.TAR, .TAR_GNUTAR]
    private var filters: [libarchiveFilter] = [.GZip, .BZip2]

    var body: some View {
        @Bindable var viewModel = viewModel

        HStack {
            Picker(selection: $viewModel.format, label: Text("Format")) {
                ForEach(libarchiveFormat.allCases.filter{ $0.canWrite }) { format in
                    Text(format.description)
                        .tag(format)
                }
            }
            .padding()

            if (filteredFormats.contains(viewModel.format)) {
                Picker(selection: $viewModel.filter, label: Text("Compression")) {
                    ForEach(filters) { filter in
                        Text(filter.description)
                            .tag(filter)
                    }
                }
            }
        }
//        .onChange(of: viewModel.selectedFormat, initial: true) {
//            print("\(viewModel.selectedFormat.rawValue):: \(viewModel.selectedFormat)")
//        }
    }
}
