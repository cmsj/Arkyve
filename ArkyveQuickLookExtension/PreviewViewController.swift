//
//  PreviewViewController.swift
//  ArkyveQuickLookExtension
//
//  Created by Chris Jones on 23/05/2025.
//

import Cocoa
import Quartz
import SwiftUI
import AppKit

struct QLTableRowTreeContent: TableRowContent {
    let node: ArchiveEntry
    @State private var isExpanded = true

    var tableRowBody: some TableRowContent<ArchiveEntry> {
        ForEach(node.children ?? []) { child in
            if let _ = child.children {
                @Bindable var child = child
                DisclosureTableRow(child, isExpanded: $isExpanded) {
                    QLTableRowTreeContent(node: child)
                }
            } else {
                TableRow(child)
            }
        }
    }
}

struct ArkyveQuickLookView: View {
    @State var viewModel: ArchiveViewModel
    @ScaledMetric(relativeTo: .body) var iconSize: CGFloat = 16
    @AppStorage("QLArchiveEntryTableConfig") private var columnCustomization: TableColumnCustomization<ArchiveEntry>

    var body: some View {
        VStack {
            HStack {
                Spacer()
                Text(viewModel.errors.error?.localizedDescription ?? "Unknown Error")
                Spacer()
            }
            .padding([.top, .bottom], 2)
            .background(Color(#colorLiteral(red: 0.7470226884, green: 0, blue: 0, alpha: 0.5411817071)))
            .hide(if: viewModel.errors.error == nil)

            HStack {
                Spacer()
                Text("Preview truncated to 150 entries")
                Spacer()
            }
            .padding([.top, .bottom], 2)
            .background(.gray)
            .hide(if: !viewModel.didTruncate)

            Table(of: ArchiveEntry.self, selection: $viewModel.selectedEntries, sortOrder: $viewModel.sortOrder, columnCustomization: $columnCustomization) {
                Group {
                    TableColumn("Name", value: \ArchiveEntry.name) { entry in
                        HStack {
                            Image(nsImage: NSWorkspace.shared.icon(for: entry.utType))
                                .resizable()
                                .scaledToFit()
                                .frame(height: iconSize)
                            Text(entry.name)
                        }
                        .accessibilityElement()
                        .accessibilityLabel("Name")
                        .accessibilityValue(entry.name)
                    }
                    .disabledCustomizationBehavior(.visibility)
                    .customizationID("name")

                    TableColumn("Size", value: \ArchiveEntry.sizeStringHuman) { entry in
                        Text(entry.sizeStringHuman)
                            .foregroundStyle(.secondary)
                    }
                    .customizationID("sizeStringHuman")
                    .alignment(.trailing)

                    TableColumn("Size (bytes)", value: \ArchiveEntry.sizeString) { entry in
                        Text(entry.sizeString)
                            .foregroundStyle(.secondary)
                    }
                    .customizationID("sizeString")
                    .alignment(.trailing)
                    .defaultVisibility(.hidden)
                    TableColumn("Kind", value: \ArchiveEntry.type.userString) { entry in
                        Text(entry.type.userString)
                            .foregroundStyle(.secondary)
                    }
                    .customizationID("type")
                    .defaultVisibility(.hidden)
                }

                Group {
                    TableColumn("Date Modified", value: \ArchiveEntry.mtime.finderFormatted) { entry in
                        Text(entry.mtime.finderFormatted)
                            .foregroundStyle(.secondary)
                            .accessibilityLabel("Date Modified")
                            .accessibilityValue(entry.mtime.finderFormatted)
                    }
                    .customizationID("mtime")

                    TableColumn("Date Changed", value: \ArchiveEntry.ctime.finderFormatted) { entry in
                        Text(entry.ctime.finderFormatted)
                            .foregroundStyle(.secondary)
                            .accessibilityLabel("Date Changed")
                            .accessibilityValue(entry.ctime.finderFormatted)
                    }
                    .customizationID("ctime")
                    .defaultVisibility(.hidden)

                    TableColumn("Date Accessed", value: \ArchiveEntry.atime.finderFormatted) { entry in
                        Text(entry.atime.finderFormatted)
                            .foregroundStyle(.secondary)
                            .accessibilityLabel("Date Accessed")
                            .accessibilityValue(entry.atime.finderFormatted)
                    }
                    .customizationID("atime")
                    .defaultVisibility(.hidden)

                    TableColumn("Date Created", value: \ArchiveEntry.btime.finderFormatted) { entry in
                        Text(entry.btime.finderFormatted)
                            .foregroundStyle(.secondary)
                            .accessibilityLabel("Date Created")
                            .accessibilityValue(entry.btime.finderFormatted)
                    }
                    .customizationID("btime")
                    .defaultVisibility(.hidden)
                }
                Group {
                    TableColumn("Permissions", value: \ArchiveEntry.permsString) { entry in
                        Text(entry.perms.string)
                            .foregroundStyle(.secondary)
                            .accessibilityLabel("POSIX Permissions")
                            .accessibilityValue(entry.permsAccessibilityString)
                    }
                    .customizationID("perms")
                    .defaultVisibility(.hidden)
                    TableColumn("UID", value: \ArchiveEntry.uidString) { entry in
                        Text(entry.uidString)
                            .foregroundStyle(.secondary)
                    }
                    .customizationID("uid")
                    .defaultVisibility(.hidden)
                    TableColumn("GID", value: \ArchiveEntry.gidString) { entry in
                        Text(entry.gidString)
                            .foregroundStyle(.secondary)
                    }
                    .customizationID("gid")
                    .defaultVisibility(.hidden)
                    TableColumn("Synthetic", value: \ArchiveEntry.isSynthesizedString) { entry in
                        Text(entry.isSynthesizedString)
                            .foregroundStyle(.secondary)
                    }
                    .customizationID("synth")
                    .defaultVisibility(.hidden)
                    TableColumn("Symlink Target", value: \ArchiveEntry.symlinkTargetString) { entry in
                        Text(entry.symlinkTargetString)
                            .foregroundStyle(.secondary)
                    }
                    .customizationID("symlinkTarget")
                    .defaultVisibility(.hidden)
                    TableColumn("Major/Minor", value: \ArchiveEntry.rdevString) { entry in
                        Text(entry.rdevString)
                            .foregroundStyle(.secondary)
                    }
                    .customizationID("rdev")
                    .defaultVisibility(.hidden)
                }
            } rows: {
                QLTableRowTreeContent(node: viewModel.root)
            }
        }
    }
}

class PreviewViewController: NSViewController, QLPreviewingController {
    override func loadView() {
        NSLog("loadView(): Creating view")
        view = NSView()
    }

    var gestureRecognizer: NSClickGestureRecognizer?

    func preparePreviewOfFile(at url: URL) async throws {
        NSLog("preparePreviewOfFile(): Preparing SwiftUI view")
        let managerBase = ManagerManagerBase.shared
        let viewModel = managerBase.createVM(url: url, truncateAt: 150)

        let swiftUIView = ArkyveQuickLookView(viewModel: viewModel)
            .frame(minWidth: 100, idealWidth: .infinity, maxWidth: .infinity)
            .frame(minHeight: 100, idealHeight: .infinity, maxHeight: .infinity)
            .background(Color(NSColor.windowBackgroundColor))

        let hostingView = NSHostingView(rootView: swiftUIView)
        hostingView.frame = CGRect(x: 0, y: 0, width: 800, height: 600)

        view.setFrameSize(hostingView.frame.size)
        view.wantsLayer = false

        view.addSubview(hostingView, positioned: .above, relativeTo: nil)

        hostingView.frame = view.bounds
        hostingView.autoresizingMask = [.width, .height]
        hostingView.frame.origin = CGPoint(x: 0, y: 0)

        hostingView.wantsLayer = true
        hostingView.layerContentsRedrawPolicy = .onSetNeedsDisplay
        hostingView.setAccessibilityRole(.group)

        // view.window?.makeFirstResponder(hostingView)
    }
}
