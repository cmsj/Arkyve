//
//  SplashView.swift
//  Arkyve
//
//  Created by Chris Jones on 05/06/2025.
//

import SwiftUI

struct SplashView: View {
    @Environment(\.openWindow) var openWindow
    @Environment(\.dismissWindow) var dismissWindow
    @State private var managerManager = ManagerManagerBase.shared
    @StateObject private var settingsManager = SettingsManager.shared

    var body: some View {
        VStack {
            VStack {
                Spacer()
                HStack {
                    Text("Arkyve")
                        .font(.system(size: 32))
                        .padding([.bottom], 30)
                        .allowsHitTesting(false)
                }
                HStack {
                    Button {
                        AKTrace("SplashView New Archive")
                        openWindow(id: "archive")
                    } label: {
                        Text("New Archive")
                            .font(.title2)
                            .padding(20)
                    }
                    .buttonStyle(.borderedProminent)
                    .clipShape(Capsule())

                    Button {
                        AKTrace("SplashView Open Archive")
                        openArchiveFromPanel(openWindow: openWindow)
                    } label: {
                        Text("Open Archive...")
                            .font(.title2)
                            .padding(20)
                    }
                    .clipShape(Capsule())
                }
                .padding([.leading, .trailing, .bottom])
            }
            .frame(width: 800, height: 200)
            .background {
                Image("Logo")
                    .frame(width: 800, height: 200, alignment: .center)
                    .opacity(0.05)
                    .mask(
                        LinearGradient(gradient: Gradient(colors: [Color.black, Color.black, Color.black, Color.black.opacity(0)]), startPoint: .top, endPoint: .bottom)
                    )
                    .allowsHitTesting(false)
            }

            VStack {
                Divider()
                    .padding(.horizontal, 20)
                    .padding([.bottom], 10)

                Text("Recents:")
                    .font(.title2)
                    .foregroundStyle(.secondary)
                    .allowsHitTesting(false)

                ScrollView {
                    LazyVGrid(
                        columns: [
                            GridItem(.flexible(minimum: 50, maximum: .infinity)),
                            GridItem(.flexible(minimum: 50, maximum: .infinity)),
                            GridItem(.flexible(minimum: 50, maximum: .infinity))
                        ],
                        alignment: .center,
                        spacing: 30
                    ) {
                        ForEach(settingsManager.recents, id: \.self) { recent in
                            Button {
                                AKTrace("SplashView Open Recent: \(recent)")
                                openArchiveFromURL(recent, openWindow: openWindow)
                            } label: {
                                VStack {
                                    Image(nsImage: NSWorkspace.shared.icon(forFile: recent.path))
                                        .resizable()
                                        .scaledToFit()
                                        .frame(width: 64, height: 64)
                                    Text(recent.lastPathComponent)
                                        .fontWeight(.bold)
                                        .lineLimit(1)
                                        .allowsTightening(true)
                                }
                            }
                            .buttonStyle(.borderless)
                        }
                    }
                    .padding()
                }
            }
        }
        .ignoresSafeArea()
        .frame(width: 800, height: 600)
        .onChange(of: managerManager.vmStoreIsEmpty, initial: true) { wasEmpty, isEmpty in
            // NOTE: This is one half of a behaviour - the other half is an equivalent onChange in ArkyveApp
            if !isEmpty {
                dismissWindow()
            }
        }
        .onChange(of: settingsManager.autoSplashWindow) { oldValue, newValue in
            // NOTE: This is one half of a behaviour - the other half is an equivalent onChange in ArkyveApp
            if newValue == false && managerManager.vmStoreIsEmpty {
                print("Closing window")
                dismissWindow()
            }
        }
    }
}

#Preview {
    SplashView()
}
