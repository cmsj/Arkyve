//
//  ArchiveEntryPasteboardWriter.swift
//  Arkyve
//
//  Created by Chris Jones on 06/05/2025.
//

import AppKit
import UniformTypeIdentifiers

class ArchiveEntryPasteboardWriter: NSObject, NSPasteboardWriting {
    let entry: ArchiveEntryExtractable?
    let fileURLData: Data?

    init(entry: ArchiveEntryExtractable? = nil, fileURLData: Data? = nil) {
        self.entry = entry
        self.fileURLData = fileURLData
        super.init()
    }

    // Declare the types of data this object can write to the pasteboard
    func writableTypes(for pasteboard: NSPasteboard) -> [NSPasteboard.PasteboardType]
    {
        // We primarily offer our custom type which contains the encoded struct.
        // The system might derive other types (like file promises based on the
        // DataRepresentation) when using Transferable APIs, but for direct
        // writeObjects, we focus on what this writer explicitly provides.
        return [.archiveEntryExtractable, .fileURL]
    }

    // Provide the data for the requested type
    func pasteboardPropertyList(
        forType type: NSPasteboard.PasteboardType
    ) -> Any? {
        switch type {
        case .archiveEntryExtractable:
            // Encode the *entire struct* into Data using JSONEncoder
            do {
                let encoder = JSONEncoder()
                // Configure encoder if needed (e.g., date strategies)
                return try encoder.encode(entry)
            } catch {
                print(
                    "Error encoding ArchiveEntryExtractable for pasteboard: \(error)"
                )
                return nil
            }
        case .fileURL:
            return fileURLData
        default:
            // This specific writer only knows how to provide the encoded struct.
            print("Unsupported type requested by pasteboard: \(type.rawValue)")
            return nil
        }
    }
}

// --- Helper Extension for NSPasteboard.PasteboardType ---
extension NSPasteboard.PasteboardType {
    static let archiveEntryExtractable = NSPasteboard.PasteboardType(
        UTType.archiveEntryExtractable.identifier
    )
}
