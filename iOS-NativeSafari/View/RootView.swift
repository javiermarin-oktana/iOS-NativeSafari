//
//  RootView.swift
//  iOS-NativeSafari
//

import Foundation
import SwiftUI

struct RootView: View {
    @EnvironmentObject private var appLanguage: AppLanguage
    @State private var isConfigured: Bool = false
    @State private var configuredURL: String = ""

    var body: some View {
        ZStack {
            if !isConfigured {
                // Configuration screen (Google-like)
                URLConfigurationView(
                    chatServiceURL: $configuredURL,
                    isConfigured: $isConfigured,
                    onConfirm: { url in
                        await handleConfirm(url: url)
                    }
                )
                .environment(\.locale, .init(identifier: "en"))
                .transition(.opacity)
                .zIndex(2)

            } else {
                // Browser view — direct, no lock screen
                if #available(iOS 26.0, *) {
                    let browserURL = URL(string: configuredURL) ?? URL(string: "about:blank")!
                    SafariBrowserView(url: browserURL, showChrome: true)
                        .zIndex(0)
                }
            }
        }
        .ignoresSafeArea()
        .onAppear {
            if let saved = UserDefaults.standard.string(forKey: "chatServiceURL"), !saved.isEmpty {
                configuredURL = saved
            }
        }
    }

    // MARK: - Confirm handler
    @MainActor
    private func handleConfirm(url: String) async {
        NetworkService.shared.baseURL = url

        let config: AppConfig? = await withCheckedContinuation { continuation in
            NetworkService.shared.fetchChatConfig { result in
                switch result {
                case .success(let c): continuation.resume(returning: c)
                case .failure:        continuation.resume(returning: nil)
                }
            }
        }

        appLanguage.apply(config?.language)
        withAnimation(.easeInOut(duration: 0.3)) { isConfigured = true }
    }
}
