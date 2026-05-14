//
//  RootView.swift
//  iOS-NativeSafari
//

import Foundation
import SwiftUI

struct RootView: View {
    @EnvironmentObject private var appLanguage: AppLanguage
    @StateObject private var lockVM = LockScreenViewModel()
    @State private var lockScreenOffset: CGFloat = 0
    @State private var isLocked: Bool = true
    @State private var isConfigured: Bool = false
    @State private var configuredURL: String = ""
    @State private var statusBarSettings: StatusBarSettings? = nil
    @State private var screenHeight: CGFloat = 852

    var progress: Double {
        let percentage = -lockScreenOffset / screenHeight
        return max(0, min(percentage, 1))
    }

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
                // Browser view
                if #available(iOS 26.0, *) {
                    let browserURL = URL(string: configuredURL) ?? URL(string: "about:blank")!
                    SafariBrowserView(url: browserURL, onLock: lock)
                        .scaleEffect(isLocked ? 0.94 + (0.06 * progress) : 1.0)
                        .blur(radius: isLocked ? (1.0 - progress) * 3 : 0)
                        .overlay(
                            Color.black
                                .opacity(isLocked ? 0.3 - (0.3 * progress) : 0)
                                .ignoresSafeArea()
                                .allowsHitTesting(false)
                        )
                        .zIndex(0)
                }

                // Lock screen overlay
                if isLocked {
                    if #available(iOS 26.0, *) {
                        LockScreenView(
                            viewModel: lockVM,
                            offset: $lockScreenOffset,
                            opacity: .constant(1.0 - (progress * 1.5))
                        )
                        .offset(y: lockScreenOffset)
                        .clipShape(RoundedRectangle(cornerRadius: pow(progress, 0.4) * 54, style: .continuous))
                        .scaleEffect(1 - progress * 0.04)
                        .gesture(
                            DragGesture()
                                .onChanged { value in
                                    if value.translation.height < 0 {
                                        lockScreenOffset = value.translation.height
                                    }
                                }
                                .onEnded { value in
                                    if value.translation.height < -150 || value.velocity.height < -800 {
                                        unlock()
                                    } else {
                                        withAnimation(.interpolatingSpring(stiffness: 250, damping: 25)) {
                                            lockScreenOffset = 0
                                        }
                                    }
                                }
                        )
                        .zIndex(1)
                        .transition(.identity)
                        .statusBarHidden(true)
                    }
                }
            }
        }
        .background(
            GeometryReader { geo in
                Color.black
                    .onAppear { screenHeight = geo.size.height }
                    .onChange(of: geo.size.height) { _, h in screenHeight = h }
            }
            .ignoresSafeArea()
        )
        .ignoresSafeArea()
        .onAppear {
            if let saved = UserDefaults.standard.string(forKey: "chatServiceURL"), !saved.isEmpty {
                configuredURL = saved
            }
        }
    }

    // MARK: - Confirm handler: fetch config for language/statusBar, then show lock screen
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
        statusBarSettings = config?.statusBar?.lockscreen

        withAnimation(.easeInOut(duration: 0.3)) { isConfigured = true }
    }

    // MARK: - Lock (volver al lock screen)
    func lock() {
        UIImpactFeedbackGenerator(style: .heavy).impactOccurred()
        withAnimation(.interpolatingSpring(stiffness: 180, damping: 20)) {
            isLocked = true
        }
    }

    // MARK: - Unlock animation
    func unlock() {
        UIImpactFeedbackGenerator(style: .medium).impactOccurred()
        withAnimation(.interpolatingSpring(stiffness: 180, damping: 20)) {
            lockScreenOffset = -screenHeight
        }
        DispatchQueue.main.asyncAfter(deadline: .now() + 0.45) {
            isLocked = false
            lockScreenOffset = 0
        }
    }
}
