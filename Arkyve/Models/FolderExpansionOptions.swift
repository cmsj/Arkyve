//
//  FolderExpansionOptions.swift
//  Arkyve
//
//  Created by Chris Jones on 09/06/2025.
//


enum FolderExpansionOptions: String, CaseIterable, Identifiable {
    case never, oneOnly, always
    var id: Self { self }

    var description: String {
        switch(self) {
        case .never:
            "Never"
        case .oneOnly:
            "When archive contains only one folder"
        case .always:
            "Always"
        }
    }
}
