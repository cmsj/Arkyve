//
//  SplashView.swift
//  Arkyve
//
//  Created by Chris Jones on 05/06/2025.
//

import SwiftUI

@MainActor
@Observable
final class SplashViewModel: WindowAccessorDelegate {
    weak var window: NSWindow? = nil
}

struct WelcomeButton: View {
    var iconName: String
    var text: String

    var body: some View {
        HStack(spacing: 0) {
            Image(systemName: iconName)
                .font(.system(size: 16, weight: .medium))
                .foregroundStyle(.secondary)
                .padding(10)
                .frame(width: 38)
//                                        .border(.blue)
            Text(text)
                .font(.system(size: 14, weight: .medium))
                .padding([.leading], 0)
//                                        .border(.orange)
            Spacer()
        }
        .background(
            RoundedRectangle(
                cornerRadius: 7,
                style: .continuous
            )
            .fill(.gray.opacity(0.1))
        )
        .frame(width: 349, height: 35)
        .padding([.bottom], 7)
//        .border(.cyan)
    }
}
struct SplashView: View {
    @Environment(\.openWindow) var openWindow
    @Environment(\.dismissWindow) var dismissWindow
    @Environment(\.colorScheme) var colorScheme: ColorScheme

    @State var viewModel = SplashViewModel()
    @State private var managerManager = ManagerManager.shared
    @StateObject private var settingsManager = SettingsManager.shared
    @State private var selection: URL?
    private var homeDir: String
    private var glowColor = Color(red: 0.984, green: 0.537, blue: 0.122, opacity: 0.6) // FB891F
    @State private var closeHover: Bool = false

    init() {
        let pw = getpwuid(getuid())
        let home = pw?.pointee.pw_dir
        homeDir = FileManager.default.string(withFileSystemRepresentation: home!, length: Int(strlen(home!))).appending("/")
    }

    var body: some View {
        ZStack {
            // Hide an NSWindow accessing view that we need to use to hide our traffic lights buttons
            NSWindowAccessor(delegate: viewModel)
                .frame(width: 0, height: 0)
            HStack(spacing: 0) {
                ZStack {
                    Rectangle()
                        .fill(colorScheme == .dark ? .black.opacity(0.3) : .white)
                        .allowsHitTesting(false)
                    VStack(spacing: 0) {
                        CloseButton()
                            .position(x: 18, y: 32)
                            .ignoresSafeArea()
                        VStack(spacing: 0) {
                            Image(.arkyveLogo)
                                .resizable()
                                .frame(width: 103, height: 103, alignment: .center)
                                .clipShape(.buttonBorder)
                                .shadow(color: colorScheme == .dark ? glowColor : .clear, radius: 50)
                                .padding([.top], 65)
                            Text("Arkyve")
                                .font(.system(size: 32))
                                .fontWeight(.bold)
                                .padding([.top], 14)
                            Text("Version \(AppInfo.shared.version)")
                                .font(.system(size: 14))
                                .foregroundStyle(.secondary)
                        }
                        .frame(height: 278)
                        .allowsHitTesting(false)
                        //                    .border(.green)
                        
                        VStack(spacing: 0) {
                            WelcomeButton(iconName: "plus.app",
                                          text: "Create New Archive...")
                            .onTapGesture {
                                AKTrace("SplashView New Archive")
                                dismissWindow()
                                openWindow(id: "archive")
                            }
                            
                            WelcomeButton(iconName: "folder",
                                          text: "Open Existing Archive...")
                            .onTapGesture {
                                AKTrace("SplashView Open Archive")
                                dismissWindow()
                                openArchiveFromPanel(openWindow: openWindow, wasSplash: true)
                            }
                            
                            WelcomeButton(iconName: "folder",
                                          text: "Unused")
                            .padding([.bottom], 41)
                            .opacity(0)
                            
                        }
                        .frame(height: 238)
                        //                    .border(.yellow)
                    }
                    .frame(width: 460)
                }
                //            .border(.red)
                
                ScrollViewReader { proxy in
                    VStack {
                        Text("Recent archives:")
                            .fontWeight(.bold)
                            .textCase(.uppercase)
                            .foregroundStyle(.secondary)
                            .padding([.top])
                        List(selection: $selection) {
                            ForEach(settingsManager.recents, id: \.self) { recent in
                                HStack {
                                    Image(nsImage: NSWorkspace.shared.icon(forFile: recent.path))
                                        .resizable()
                                        .scaledToFit()
                                        .frame(width: 32, height: 32)
                                    VStack(alignment: .leading) {
                                        Text(recent.lastPathComponent)
                                            .fontWeight(.bold)
                                            .lineLimit(1)
                                            .allowsTightening(true)
                                        Text(recent.path.replacing(homeDir, with: ""))
                                            .foregroundStyle(.secondary)
                                            .font(.caption)
                                            .lineLimit(1)
                                            .allowsTightening(true)
                                    }
                                }
                                .listRowSeparator(.hidden)
                                .padding(.vertical, 4)
                                .onTapGesture {
                                    selection = recent
                                }
                                .simultaneousGesture(TapGesture(count: 2).onEnded {
                                    AKTrace("Opening recent: \(recent)")
                                    dismissWindow()
                                    openArchiveFromURL(recent, openWindow: openWindow)
                                })
                            }
                        }
                        .scrollContentBackground(.hidden)
                    }
                    .ignoresSafeArea(.all)
                    .onChange(of: settingsManager.recents, initial: true) {
                        proxy.scrollTo(settingsManager.recents.first, anchor: .top)
                    }
                }
            }
            .ignoresSafeArea()
            .frame(width: 741, height: 433)
            .onChange(of: settingsManager.autoSplashWindow) { oldValue, newValue in
                // NOTE: This is one half of a behaviour - the other half is an equivalent onChange in ArkyveApp
                if newValue == false && managerManager.vmStoreIsEmpty {
                    print("Closing window")
                    dismissWindow()
                }
            }
            .onChange(of: viewModel.window) { _, _ in
                // Hide the traffic light buttons if we now have a valid NSWindow
                guard let window = viewModel.window else { return }
                window.standardWindowButton(.closeButton)?.isHidden = true
                window.standardWindowButton(.zoomButton)?.isHidden = true
                window.standardWindowButton(.miniaturizeButton)?.isHidden = true
            }
        }
    }
}

#Preview {
    SplashView()
}
