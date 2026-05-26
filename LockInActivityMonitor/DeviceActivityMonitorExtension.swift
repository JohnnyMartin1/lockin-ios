//
//  DeviceActivityMonitorExtension.swift
//  LockInActivityMonitor
//
//  Hot path: receive DeviceActivity callbacks → resolve clip from the App
//  Group `SharedLockInConfiguration` → schedule a local notification.
//
//  Every callback also writes to `ScreenTimeDebugLogStore` so the main app
//  can render extension activity in its Developer Debug panel — extensions
//  are otherwise very hard to attach to in Xcode.
//

import DeviceActivity
import Foundation
import UserNotifications

// NSExtensionPrincipalClass in Info.plist →
// `$(PRODUCT_MODULE_NAME).DeviceActivityMonitorExtension`
class DeviceActivityMonitorExtension: DeviceActivityMonitor {

    // MARK: - Init

    override init() {
        super.init()
        // Probe the App Group container — if this can't be opened, the
        // extension's entitlements are wrong and no shared data will flow.
        if UserDefaults(suiteName: SharedLockInConstants.appGroupIdentifier) == nil {
            print("[LockInExtension] FATAL: App Group UserDefaults unavailable (\(SharedLockInConstants.appGroupIdentifier)). "
                  + "Extension entitlements may be missing.")
        }
        ScreenTimeDebugLogStore.append(.ext, "LockInActivityMonitor initialized — DeviceActivityMonitor subclass loaded.")
        print("[LockInExtension] initialized")
    }

    // MARK: - Logging helper

    /// Mirrors a line to both the system log (visible in Console.app) and the
    /// App Group debug log (visible in StartLockInView's Developer Debug).
    private func log(_ message: String) {
        print("[LockInExtension] \(message)")
        ScreenTimeDebugLogStore.append(.ext, message)
    }

    // MARK: - Lifecycle callbacks

    override func intervalDidStart(for activity: DeviceActivityName) {
        super.intervalDidStart(for: activity)
        log("intervalDidStart activity=\(activity.rawValue)")
        logExpectedActivityMatch(activity: activity, context: "intervalDidStart")

        // Diagnostic: when the Test Extension Wakeup interval kicks in, fire
        // a notification so the user has visible proof the extension woke.
        if activity.rawValue == SharedLockInConstants.ActivityName.debugWake {
            scheduleDebugWakeNotification(
                suffix: "start",
                body: "DeviceActivity extension woke up."
            )
        }
    }

    override func intervalDidEnd(for activity: DeviceActivityName) {
        super.intervalDidEnd(for: activity)
        log("intervalDidEnd activity=\(activity.rawValue)")

        if activity.rawValue == SharedLockInConstants.ActivityName.lockInSession {
            var config = SharedConfigurationStore.shared.load()
            if config.lockInSessionStartedAt != nil || config.lockInSessionEndsAt != nil {
                config.lockInSessionStartedAt = nil
                config.lockInSessionEndsAt   = nil
                SharedConfigurationStore.shared.save(config)
                log("cleared LockIn session window after intervalDidEnd.")
            }
        }

        if activity.rawValue == SharedLockInConstants.ActivityName.debugWake {
            scheduleDebugWakeNotification(
                suffix: "end",
                body: "DeviceActivity extension interval ended."
            )
        }
    }

    override func intervalWillStartWarning(for activity: DeviceActivityName) {
        super.intervalWillStartWarning(for: activity)
        log("intervalWillStartWarning activity=\(activity.rawValue)")
    }

    override func intervalWillEndWarning(for activity: DeviceActivityName) {
        super.intervalWillEndWarning(for: activity)
        log("intervalWillEndWarning activity=\(activity.rawValue)")
    }

    override func eventWillReachThresholdWarning(_ event: DeviceActivityEvent.Name, activity: DeviceActivityName) {
        super.eventWillReachThresholdWarning(event, activity: activity)
        log("eventWillReachThresholdWarning event=\(event.rawValue) activity=\(activity.rawValue)")
    }

    // MARK: - The hot path

    override func eventDidReachThreshold(_ event: DeviceActivityEvent.Name, activity: DeviceActivityName) {
        super.eventDidReachThreshold(event, activity: activity)

        let isDailyEvent = event.rawValue == SharedLockInConstants.EventName.dailyLimitReached
        let isLockInSlip = event.rawValue == SharedLockInConstants.EventName.lockInSlipThresholdReached

        log("eventDidReachThreshold event=\(event.rawValue) activity=\(activity.rawValue) "
            + "isDailyLimitReached=\(isDailyEvent) isLockInSlipThresholdReached=\(isLockInSlip)")

        // ── Diagnostic marker: prove the extension can post a notification
        //    independently of voice resolution / shared config.
        //    TEMPORARY — remove once the real notification consistently fires.
        scheduleDebugMarkerNotification(for: activity)

        let store = SharedConfigurationStore.shared
        let configuration = store.load()

        if configuration.selectedCharacterId.isEmpty && configuration.resolvedClips.isEmpty {
            log("ERROR: SharedLockInConfiguration missing voice data — will use fallback notification body.")
        } else {
            log("SharedLockInConfiguration loaded OK")
        }
        log("  characterId=\(configuration.selectedCharacterId.isEmpty ? "—" : configuration.selectedCharacterId) "
            + "clipIds=\(configuration.selectedClipIds.count) resolvedClips=\(configuration.resolvedClips.count) "
            + "shuffle=\(configuration.shuffleSayings) cooldownMin=\(configuration.cooldownMinutes)")

        if isInCooldown(configuration) {
            log("Within cooldown — skipping real alert.")
            return
        }

        let payload = chooseClipPayload(from: configuration)
        log("  selectedClipId=\(payload?.id ?? "fallback")")
        log("  notificationBody=\(payload?.notificationText ?? "Time to get back to it.")")

        scheduleAlert(for: activity, payload: payload) { [weak self] success in
            self?.log("notification scheduling \(success ? "SUCCEEDED" : "FAILED")")
        }
        store.markAlertFired(at: Date())
    }

    // MARK: - Cooldown

    private func isInCooldown(_ configuration: SharedLockInConfiguration) -> Bool {
        guard let lastFired = configuration.lastAlertFiredAt else {
            log("  cooldown: no prior alert")
            return false
        }
        let cooldownSeconds = TimeInterval(max(0, configuration.cooldownMinutes) * 60)
        guard cooldownSeconds > 0 else {
            log("  cooldown: disabled (0 min)")
            return false
        }
        let elapsed = Date().timeIntervalSince(lastFired)
        if elapsed < cooldownSeconds {
            log("  cooldown ACTIVE: \(Int(elapsed))s elapsed / \(Int(cooldownSeconds))s")
            return true
        }
        log("  cooldown: clear (\(Int(elapsed))s since last alert)")
        return false
    }

    // MARK: - Clip selection

    private func chooseClipPayload(from configuration: SharedLockInConfiguration) -> SharedVoiceClipPayload? {
        let payloads = configuration.resolvedClips
        guard !payloads.isEmpty else { return nil }
        if configuration.shuffleSayings && payloads.count > 1 {
            return payloads.randomElement()
        }
        return payloads.first
    }

    // MARK: - Notification scheduling

    /// TEMPORARY diagnostic — fires when a Test Extension Wakeup interval
    /// starts or ends. Confirms the extension is alive and can post
    /// notifications independent of the LockIn voice flow.
    private func scheduleDebugWakeNotification(suffix: String, body: String) {
        let content = UNMutableNotificationContent()
        content.title = "LOCK IN DEBUG"
        content.body  = body
        content.sound = .default

        let identifier = "lockin.notification.debug.wake.\(suffix)"
        let request = UNNotificationRequest(identifier: identifier, content: content, trigger: nil)

        UNUserNotificationCenter.current().add(request) { [weak self] error in
            if let error {
                self?.log("debug wake notification FAILED id=\(identifier): \(error)")
            } else {
                self?.log("debug wake notification scheduled id=\(identifier)")
            }
        }
    }

    /// TEMPORARY diagnostic — fires a simple notification immediately so we can
    /// distinguish "extension didn't run" from "extension ran but didn't post".
    /// Remove once the real LockIn alert is consistently delivered.
    private func scheduleDebugMarkerNotification(for activity: DeviceActivityName) {
        let content = UNMutableNotificationContent()
        content.title = "LOCK IN DEBUG"
        content.body  = "DeviceActivity threshold reached."
        content.sound = .default

        let identifier = "lockin.notification.debug.\(activity.rawValue)"
        let request = UNNotificationRequest(identifier: identifier, content: content, trigger: nil)

        UNUserNotificationCenter.current().add(request) { [weak self] error in
            if let error {
                self?.log("debug marker notification FAILED id=\(identifier): \(error)")
            } else {
                self?.log("debug marker notification scheduled id=\(identifier)")
            }
        }
    }

    private func scheduleAlert(
        for activity: DeviceActivityName,
        payload: SharedVoiceClipPayload?,
        completion: @escaping (Bool) -> Void
    ) {
        let content = UNMutableNotificationContent()
        content.title = "LOCK IN"
        content.body  = payload?.notificationText ?? "Time to get back to it."
        content.sound = resolvedSound(for: payload?.soundFileName)

        let identifier = notificationIdentifier(for: activity)
        let request = UNNotificationRequest(identifier: identifier, content: content, trigger: nil)

        UNUserNotificationCenter.current().add(request) { [weak self] error in
            if let error {
                self?.log("real alert FAILED id=\(identifier): \(error)")
                completion(false)
            } else {
                self?.log("real alert scheduled id=\(identifier) clip=\(payload?.id ?? "fallback")")
                completion(true)
            }
        }
    }

    private func notificationIdentifier(for activity: DeviceActivityName) -> String {
        switch activity.rawValue {
        case SharedLockInConstants.ActivityName.dailyLimit:
            return SharedLockInConstants.NotificationIdentifier.dailyLimit
        case SharedLockInConstants.ActivityName.lockInSession:
            return SharedLockInConstants.NotificationIdentifier.lockInSession
        default:
            return "lockin.notification.activity.\(activity.rawValue)"
        }
    }

    private func logExpectedActivityMatch(activity: DeviceActivityName, context: String) {
        let daily  = SharedLockInConstants.ActivityName.dailyLimit
        let lockIn = SharedLockInConstants.ActivityName.lockInSession
        let wake   = SharedLockInConstants.ActivityName.debugWake
        log("  \(context): matches dailyLimit=\(activity.rawValue == daily) "
            + "lockInSession=\(activity.rawValue == lockIn) "
            + "debugWake=\(activity.rawValue == wake)")
    }

    // MARK: - Sound resolution (extension bundle)

    private func resolvedSound(for fileName: String?) -> UNNotificationSound {
        guard let fileName, !fileName.isEmpty else { return .default }
        let ext  = (fileName as NSString).pathExtension
        let base = (fileName as NSString).deletingPathExtension
        if !base.isEmpty,
           Bundle.main.url(forResource: base, withExtension: ext.isEmpty ? nil : ext) != nil {
            return UNNotificationSound(named: UNNotificationSoundName(rawValue: fileName))
        }
        log("Sound file \(fileName) not found in extension bundle — using default sound.")
        return .default
    }
}
