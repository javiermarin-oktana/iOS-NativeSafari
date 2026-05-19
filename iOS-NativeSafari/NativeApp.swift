//
//  NativeApp.swift
//  NativeApp
//
//  Created by Andres Marinn on 13/02/26.
//

import SwiftUI
import AVFoundation

@main
struct NativeApp: App {
    @StateObject private var appLanguage = AppLanguage()

    init() {
        requestMediaPermissions()
    }

    var body: some Scene {
        WindowGroup {
            RootView()
                .environmentObject(appLanguage)
                .environment(\.locale, appLanguage.locale)
                .environment(\.localizationBundle, appLanguage.bundle)
        }
    }

    private func requestMediaPermissions() {
        AVCaptureDevice.requestAccess(for: .video) { _ in }
        AVCaptureDevice.requestAccess(for: .audio) { _ in }
    }
}
