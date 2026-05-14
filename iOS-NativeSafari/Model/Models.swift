//
//  Models.swift
//  iOS-NativeSafari
//

import Foundation

// MARK: - Root config model
struct AppConfig: Codable {
    let configName: String
    let language: String?
    let statusBar: StatusBarConfig?
    let notifications: [NotificationConfig]?
}

// MARK: - Status bar
struct StatusBarConfig: Codable {
    let lockscreen: StatusBarSettings?
    let chatview: StatusBarSettings?
}

struct StatusBarSettings: Codable {
    let carrier: String?
    let signalBars: Int?
    let wifiStrength: Int?
    let showWifi: Bool?
    let levelBattery: Double?
    let isCharging: Bool?
}

// MARK: - Notification config (lock screen notifications)
struct NotificationConfig: Codable, Identifiable {
    let id: UUID
    let appName: String?
    let iconName: String?
    let iconColor: String?
    let imageName: String?
    let documentIcon: String?
    let title: String?
    let message: String?
    let timeAgo: String?

    enum CodingKeys: String, CodingKey {
        case appName, iconName, iconColor, imageName, documentIcon, title, message, timeAgo
    }

    init(from decoder: Decoder) throws {
        let c = try decoder.container(keyedBy: CodingKeys.self)
        self.id           = UUID()
        self.appName      = try c.decodeIfPresent(String.self, forKey: .appName)
        self.iconName     = try c.decodeIfPresent(String.self, forKey: .iconName)
        self.iconColor    = try c.decodeIfPresent(String.self, forKey: .iconColor)
        self.imageName    = try c.decodeIfPresent(String.self, forKey: .imageName)
        self.documentIcon = try c.decodeIfPresent(String.self, forKey: .documentIcon)
        self.title        = try c.decodeIfPresent(String.self, forKey: .title)
        self.message      = try c.decodeIfPresent(String.self, forKey: .message)
        self.timeAgo      = try c.decodeIfPresent(String.self, forKey: .timeAgo)
    }

    func encode(to encoder: Encoder) throws {
        var c = encoder.container(keyedBy: CodingKeys.self)
        try c.encodeIfPresent(appName,      forKey: .appName)
        try c.encodeIfPresent(iconName,     forKey: .iconName)
        try c.encodeIfPresent(iconColor,    forKey: .iconColor)
        try c.encodeIfPresent(imageName,    forKey: .imageName)
        try c.encodeIfPresent(documentIcon, forKey: .documentIcon)
        try c.encodeIfPresent(title,        forKey: .title)
        try c.encodeIfPresent(message,      forKey: .message)
        try c.encodeIfPresent(timeAgo,      forKey: .timeAgo)
    }
}
