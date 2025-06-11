//
//  AboutView.swift
//  Arkyve
//
//  Created by Chris Jones on 11/06/2025.
//

import SwiftUI

struct AboutView: View {
    @Environment(\.openURL) var openURL
    @Environment(\.dismissWindow) var dismissWindow
    private var glowColor = Color(red: 0.2, green: 0.576, blue: 0.807, opacity: 0.6) // 3493CE

    var body: some View {
        HStack(spacing: 0) {
            ZStack {
                Rectangle()
                    .fill(.black.opacity(0.3))
                    .allowsHitTesting(false)
                VStack(spacing: 0) {
                    VStack(spacing: 0) {
                        Image("Logo")
                            .resizable()
                            .frame(width: 103, height: 103, alignment: .center)
                            .clipShape(.buttonBorder)
                            .shadow(color: glowColor, radius: 50)
                            .padding([.top], 30)
                            .allowsHitTesting(false)
                        Text("Arkyve")
                            .font(.system(size: 32))
                            .fontWeight(.bold)
                            .padding([.top], 14)
                            .allowsHitTesting(false)
                        Text("Version \(AppInfo.shared.version) (\(AppInfo.shared.build))")
                            .font(.system(size: 14))
                            .foregroundStyle(.secondary)
                            .allowsHitTesting(false)
                        Text(AppInfo.shared.copyrightNotice)
                            .padding([.top, .bottom])
                            .allowsHitTesting(false)
                        Divider()
                            .padding()
                            .allowsHitTesting(false)
                        VStack {
                            Text("Arkyve would not be possible without the incredible work of Tim Kientzle and all the contributors to libarchive.")
                                .multilineTextAlignment(.center)
                                .padding([.leading, .trailing], 30)
                                .allowsHitTesting(false)
                            Text("You can view the license for libarchive here:")
                                .multilineTextAlignment(.center)
                                .allowsHitTesting(false)
                            Link("https://github.com/libarchive/libarchive/blob/master/COPYING", destination: URL(string: "https://github.com/libarchive/libarchive/blob/master/COPYING")!)
                                .font(.system(size: 14))
                                .foregroundStyle(.secondary)
                                .padding([.top], 8)
                            Image(systemName: "heart.fill")
                                .font(.system(size: 14))
                                .foregroundStyle(.red)
                                .padding([.top, .bottom], 8)
                                .allowsHitTesting(false)
                        }
                        .padding()
                    }
                    //                    .border(.green)
                }
            }
            //            .border(.red)
        }
        .ignoresSafeArea()
        .frame(width: 460, height: 433)
    }
}

#Preview {
    AboutView()
}
