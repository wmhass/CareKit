//
//  ForkNotifications.swift
//  CareKit
//
//  Created by William Hass on 2025-07-26.
//

import Foundation
extension Notification.Name {
    public static let dailyPageViewDidChangeDate = Notification.Name("Carekit.fork.dailyPageViewDidChangeDate")
}

extension NotificationCenter {
    public static var careKitFork: NotificationCenter {
        NotificationCenter.default
    }
}