//
//  AppDelegate.swift
//  LockIn
//
//  Created by Catherine Fratila on 5/20/26.
//

import UIKit
import UserNotifications

final class AppDelegate: NSObject, UIApplicationDelegate {
    func application(
        _ application: UIApplication,
        didFinishLaunchingWithOptions launchOptions: [UIApplication.LaunchOptionsKey: Any]? = nil
    ) -> Bool {
        // Force NotificationManager init so it sets itself as
        // UNUserNotificationCenter.current().delegate at launch.
        _ = NotificationManager.shared
        print("[LockIn] AppDelegate didFinishLaunching — notification delegate ready.")
        return true
    }
}
