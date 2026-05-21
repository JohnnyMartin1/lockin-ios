//
//  NotificationManager.swift
//  LockIn
//

import Combine
import Foundation
import UserNotifications

@MainActor
final class NotificationManager: NSObject, ObservableObject {
    enum AuthState: String {
        case unknown
        case authorized
        case denied
    }

    static let shared = NotificationManager()

    static let lockInRequestIdentifier = "lockin-start-notification"
    static let debugRequestIdentifier = "lockin-debug-notification"

    @Published private(set) var authState: AuthState = .unknown
    /// One of: notDetermined, denied, authorized, provisional, ephemeral, unknown.
    @Published private(set) var authorizationStatusDescription: String = "unknown"

    private override init() {
        super.init()
        UNUserNotificationCenter.current().delegate = self
        print("[LockIn] NotificationManager initialized — delegate wired.")
    }

    // MARK: - Authorization

    func refreshAuthorizationStatus() async {
        let settings = await UNUserNotificationCenter.current().notificationSettings()
        let desc: String
        switch settings.authorizationStatus {
        case .notDetermined: desc = "notDetermined"
        case .denied:        desc = "denied"
        case .authorized:    desc = "authorized"
        case .provisional:   desc = "provisional"
        case .ephemeral:     desc = "ephemeral"
        @unknown default:    desc = "unknown"
        }
        authorizationStatusDescription = desc
        print("[LockIn] Notification authorization status: \(desc)")

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
            print("[LockIn] requestAuthorization granted=\(granted)")
            await refreshAuthorizationStatus()
            return granted
        } catch {
            print("[LockIn] requestAuthorization failed: \(error)")
            authState = .denied
            authorizationStatusDescription = "denied"
            return false
        }
    }

    // MARK: - Scheduling

    @discardableResult
    func sendImmediateDebugNotification() async -> Bool {
        await refreshAuthorizationStatus()
        guard authState == .authorized else {
            print("[LockIn] sendImmediateDebugNotification skipped — auth=\(authorizationStatusDescription)")
            return false
        }

        let content = UNMutableNotificationContent()
        content.title = "LOCK IN DEBUG"
        content.body = "If you see this, notifications work."
        content.sound = .default

        let trigger = UNTimeIntervalNotificationTrigger(timeInterval: 5, repeats: false)
        let request = UNNotificationRequest(
            identifier: Self.debugRequestIdentifier,
            content: content,
            trigger: trigger
        )

        UNUserNotificationCenter.current()
            .removePendingNotificationRequests(withIdentifiers: [Self.debugRequestIdentifier])

        do {
            try await UNUserNotificationCenter.current().add(request)
            print("[LockIn] Scheduled debug notification (id=\(Self.debugRequestIdentifier)) in 5s.")
            await printPendingNotifications()
            return true
        } catch {
            print("[LockIn] Failed to schedule debug notification: \(error)")
            return false
        }
    }

    /// Schedules a LockIn alert using one of the supplied candidate clips.
    /// If `shuffle` is true and there are multiple candidates, picks one at
    /// random. With a single candidate or shuffle off, the first is used.
    @discardableResult
    func scheduleLockInAlert(
        candidates: [VoiceClip],
        shuffle: Bool,
        after seconds: TimeInterval
    ) async -> Bool {
        guard let chosen = chooseClip(from: candidates, shuffle: shuffle) else {
            print("[LockIn] scheduleLockInAlert(candidates:) skipped — no candidate clips.")
            return false
        }
        return await scheduleLockInAlert(clip: chosen, after: seconds)
    }

    /// Same selection semantics as the scheduling variant, for test/preview alerts.
    @discardableResult
    func sendTestNotification(
        candidates: [VoiceClip],
        shuffle: Bool,
        after seconds: TimeInterval = 3
    ) async -> Bool {
        guard let chosen = chooseClip(from: candidates, shuffle: shuffle) else {
            print("[LockIn] sendTestNotification(candidates:) skipped — no candidate clips.")
            return false
        }
        return await sendTestNotification(clip: chosen, after: seconds)
    }

    private func chooseClip(from candidates: [VoiceClip], shuffle: Bool) -> VoiceClip? {
        if candidates.isEmpty { return nil }
        if candidates.count == 1 || !shuffle { return candidates.first }
        return candidates.randomElement()
    }

    @discardableResult
    func scheduleLockInAlert(clip: VoiceClip, after seconds: TimeInterval) async -> Bool {
        await refreshAuthorizationStatus()
        guard authState == .authorized else {
            print("[LockIn] scheduleLockInAlert skipped — auth=\(authorizationStatusDescription)")
            return false
        }

        let content = UNMutableNotificationContent()
        content.title = "LOCK IN"
        content.body = clip.notificationText
        content.sound = resolvedSound(for: clip.soundFileName)

        let interval = max(seconds, 1)
        let trigger = UNTimeIntervalNotificationTrigger(timeInterval: interval, repeats: false)
        let request = UNNotificationRequest(
            identifier: Self.lockInRequestIdentifier,
            content: content,
            trigger: trigger
        )

        UNUserNotificationCenter.current()
            .removePendingNotificationRequests(withIdentifiers: [Self.lockInRequestIdentifier])

        do {
            try await UNUserNotificationCenter.current().add(request)
            print("[LockIn] Scheduled LockIn alert (id=\(Self.lockInRequestIdentifier)) clip=\(clip.id) in \(interval)s.")
            await printPendingNotifications()
            return true
        } catch {
            print("[LockIn] Failed to schedule LockIn alert: \(error)")
            return false
        }
    }

    func cancelLockInAlert() {
        UNUserNotificationCenter.current()
            .removePendingNotificationRequests(withIdentifiers: [Self.lockInRequestIdentifier])
        print("[LockIn] Cancelled Start LockIn alert (id=\(Self.lockInRequestIdentifier)).")
        Task { await printPendingNotifications() }
    }

    @discardableResult
    func sendTestNotification(clip: VoiceClip, after seconds: TimeInterval = 3) async -> Bool {
        await refreshAuthorizationStatus()
        guard authState == .authorized else {
            print("[LockIn] sendTestNotification skipped — auth=\(authorizationStatusDescription)")
            return false
        }

        let content = UNMutableNotificationContent()
        content.title = "LOCK IN"
        content.body = clip.notificationText
        content.sound = resolvedSound(for: clip.soundFileName)

        let interval = max(seconds, 1)
        let trigger = UNTimeIntervalNotificationTrigger(timeInterval: interval, repeats: false)
        let identifier = "lockin-test-\(clip.id)"
        let request = UNNotificationRequest(identifier: identifier, content: content, trigger: trigger)

        do {
            try await UNUserNotificationCenter.current().add(request)
            print("[LockIn] Scheduled test alert (id=\(identifier)) clip=\(clip.id) in \(interval)s.")
            await printPendingNotifications()
            return true
        } catch {
            print("[LockIn] Failed to schedule test alert: \(error)")
            return false
        }
    }

    // MARK: - Diagnostics

    func printPendingNotifications() async {
        let pending = await UNUserNotificationCenter.current().pendingNotificationRequests()
        if pending.isEmpty {
            print("[LockIn] Pending notifications: (none)")
            return
        }
        print("[LockIn] Pending notifications: \(pending.count)")
        for request in pending {
            let triggerDesc: String
            if let trigger = request.trigger as? UNTimeIntervalNotificationTrigger {
                let next = trigger.nextTriggerDate().map { "\($0)" } ?? "?"
                triggerDesc = "interval=\(trigger.timeInterval)s nextFire=\(next)"
            } else {
                triggerDesc = "trigger=\(String(describing: request.trigger))"
            }
            print("[LockIn]  • id=\(request.identifier) title=\"\(request.content.title)\" body=\"\(request.content.body)\" \(triggerDesc)")
        }
    }

    func hasPendingLockInAlert() async -> Bool {
        let pending = await UNUserNotificationCenter.current().pendingNotificationRequests()
        return pending.contains { $0.identifier == Self.lockInRequestIdentifier }
    }

    // MARK: - Sound resolution

    private func resolvedSound(for fileName: String) -> UNNotificationSound {
        let nsName = fileName as NSString
        let base = nsName.deletingPathExtension
        let ext = nsName.pathExtension

        guard !base.isEmpty, !ext.isEmpty else {
            print("[LockIn] Sound file name empty — using default sound.")
            return .default
        }

        if Bundle.main.url(forResource: base, withExtension: ext) != nil {
            return UNNotificationSound(named: UNNotificationSoundName(fileName))
        }

        print("[LockIn] Sound file \(fileName) not found in bundle — using default sound.")
        return .default
    }
}

// MARK: - Foreground presentation

extension NotificationManager: UNUserNotificationCenterDelegate {
    nonisolated func userNotificationCenter(
        _ center: UNUserNotificationCenter,
        willPresent notification: UNNotification,
        withCompletionHandler completionHandler: @escaping (UNNotificationPresentationOptions) -> Void
    ) {
        let id = notification.request.identifier
        print("[LockIn] willPresent (foreground) id=\(id)")
        completionHandler([.banner, .list, .sound])
    }

    nonisolated func userNotificationCenter(
        _ center: UNUserNotificationCenter,
        didReceive response: UNNotificationResponse,
        withCompletionHandler completionHandler: @escaping () -> Void
    ) {
        let id = response.notification.request.identifier
        print("[LockIn] didReceive response id=\(id) action=\(response.actionIdentifier)")
        completionHandler()
    }
}
