//
//  NotificationManager.swift
//  LockIn
//
//  Created by Catherine Fratila on 5/20/26.
//

import Combine
import Foundation
import UserNotifications

@MainActor
final class NotificationManager: ObservableObject {
    enum AuthState {
        case unknown
        case authorized
        case denied
    }

    static let shared = NotificationManager()

    @Published private(set) var authState: AuthState = .unknown

    private init() {}

    func refreshAuthorizationStatus() async {
        let settings = await UNUserNotificationCenter.current().notificationSettings()
        switch settings.authorizationStatus {
        case .authorized, .provisional, .ephemeral:
            authState = .authorized
        case .denied:
            authState = .denied
        case .notDetermined:
            authState = .unknown
        @unknown default:
            authState = .unknown
        }
    }

    @discardableResult
    func requestNotificationPermission() async -> Bool {
        do {
            let granted = try await UNUserNotificationCenter.current()
                .requestAuthorization(options: [.alert, .sound, .badge])
            authState = granted ? .authorized : .denied
            print("[LockIn] Notification permission granted: \(granted)")
            return granted
        } catch {
            print("[LockIn] Notification permission request failed: \(error)")
            authState = .denied
            return false
        }
    }

    func sendTestNotification(clip: LockInVoiceClip, after seconds: TimeInterval = 3) {
        let content = UNMutableNotificationContent()
        content.title = "LOCK IN"
        content.body = clip.notificationText
        content.sound = resolvedSound(for: clip.soundFileName)

        let trigger = UNTimeIntervalNotificationTrigger(
            timeInterval: max(seconds, 1),
            repeats: false
        )
        let request = UNNotificationRequest(
            identifier: "lockin.test.\(clip.id)",
            content: content,
            trigger: trigger
        )

        UNUserNotificationCenter.current().add(request) { error in
            if let error {
                print("[LockIn] Failed to schedule test notification: \(error)")
            } else {
                print("[LockIn] Scheduled test notification for clip \(clip.id) in \(seconds)s")
            }
        }
    }

    private func resolvedSound(for fileName: String) -> UNNotificationSound {
        let nsName = fileName as NSString
        let base = nsName.deletingPathExtension
        let ext = nsName.pathExtension

        guard !base.isEmpty, !ext.isEmpty else {
            return .default
        }

        if Bundle.main.url(forResource: base, withExtension: ext) != nil {
            return UNNotificationSound(named: UNNotificationSoundName(fileName))
        }

        print("[LockIn] Sound file \(fileName) not found in bundle — falling back to default.")
        return .default
    }
}
