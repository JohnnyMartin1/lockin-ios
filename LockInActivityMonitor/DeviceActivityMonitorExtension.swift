//
//  DeviceActivityMonitorExtension.swift
//  LockInActivityMonitor
//
//  Phase B foundation. Implements the extension's notification path so that
//  Phase C can simply call `DeviceActivityCenter.startMonitoring(...)` from
//  the main app and trust the alerts to fire here.
//
//  No DeviceActivity scheduling, no ManagedSettings, no shielding. Just:
//    1. Load the shared configuration written by the main app.
//    2. Enforce cooldown.
//    3. Resolve which `SharedVoiceClipPayload` to play (shuffle aware).
//    4. Post a local notification with the clip's text + custom sound,
//       falling back to default sound if the .caf is missing.
//    5. Record `lastAlertFiredAt` for the next cooldown check.
//

import DeviceActivity
import UserNotifications

// `NSExtensionPrincipalClass` in Info.plist points at
// `$(PRODUCT_MODULE_NAME).DeviceActivityMonitorExtension`, so the class name
// must stay exactly this.
class DeviceActivityMonitorExtension: DeviceActivityMonitor {

    // MARK: - Lifecycle callbacks

    override func intervalDidStart(for activity: DeviceActivityName) {
        super.intervalDidStart(for: activity)
        print("[LockInExt] intervalDidStart: \(activity.rawValue)")
    }

    override func intervalDidEnd(for activity: DeviceActivityName) {
        super.intervalDidEnd(for: activity)
        print("[LockInExt] intervalDidEnd: \(activity.rawValue)")
        // Phase B keeps this a no-op. Phase D may end the LockIn Mode session here.
    }

    override func intervalWillStartWarning(for activity: DeviceActivityName) {
        super.intervalWillStartWarning(for: activity)
    }

    override func intervalWillEndWarning(for activity: DeviceActivityName) {
        super.intervalWillEndWarning(for: activity)
    }

    override func eventWillReachThresholdWarning(_ event: DeviceActivityEvent.Name, activity: DeviceActivityName) {
        super.eventWillReachThresholdWarning(event, activity: activity)
    }

    // MARK: - The hot path

    override func eventDidReachThreshold(_ event: DeviceActivityEvent.Name, activity: DeviceActivityName) {
        super.eventDidReachThreshold(event, activity: activity)
        print("[LockInExt] eventDidReachThreshold event=\(event.rawValue) activity=\(activity.rawValue)")

        let store = SharedConfigurationStore.shared
        let configuration = store.load()

        if isInCooldown(configuration) {
            print("[LockInExt] Within cooldown — skipping alert.")
            return
        }

        let payload = chooseClipPayload(from: configuration)
        scheduleAlert(for: activity, payload: payload)
        store.markAlertFired(at: Date())
    }

    // MARK: - Cooldown

    private func isInCooldown(_ configuration: SharedLockInConfiguration) -> Bool {
        guard let lastFired = configuration.lastAlertFiredAt else { return false }
        let cooldownSeconds = TimeInterval(max(0, configuration.cooldownMinutes) * 60)
        guard cooldownSeconds > 0 else { return false }
        let elapsed = Date().timeIntervalSince(lastFired)
        if elapsed < cooldownSeconds {
            print("[LockInExt] Cooldown active: \(Int(elapsed))s elapsed, cooldown=\(Int(cooldownSeconds))s.")
            return true
        }
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

    private func scheduleAlert(for activity: DeviceActivityName, payload: SharedVoiceClipPayload?) {
        let content = UNMutableNotificationContent()
        content.title = "LOCK IN"
        content.body  = payload?.notificationText ?? "Time to get back to it."
        content.sound = resolvedSound(for: payload?.soundFileName)

        let identifier = notificationIdentifier(for: activity)
        // Trigger nil → fire as soon as the system delivers it.
        let request = UNNotificationRequest(identifier: identifier, content: content, trigger: nil)

        UNUserNotificationCenter.current().add(request) { error in
            if let error {
                print("[LockInExt] Failed to schedule alert: \(error)")
            } else {
                print("[LockInExt] Scheduled alert id=\(identifier) clip=\(payload?.id ?? "fallback")")
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

    // MARK: - Sound resolution (extension bundle)

    /// `Bundle.main` from an extension is the *extension's* bundle, not the
    /// host app's. To play a custom `.caf` from the extension, the audio file
    /// must be a member of the extension target (or both targets). If missing,
    /// we silently fall back to the default sound.
    private func resolvedSound(for fileName: String?) -> UNNotificationSound {
        guard let fileName, !fileName.isEmpty else { return .default }
        let ext  = (fileName as NSString).pathExtension
        let base = (fileName as NSString).deletingPathExtension
        if !base.isEmpty,
           Bundle.main.url(forResource: base, withExtension: ext.isEmpty ? nil : ext) != nil {
            return UNNotificationSound(named: UNNotificationSoundName(rawValue: fileName))
        }
        print("[LockInExt] Sound file \(fileName) not found in extension bundle — using default sound.")
        return .default
    }
}
