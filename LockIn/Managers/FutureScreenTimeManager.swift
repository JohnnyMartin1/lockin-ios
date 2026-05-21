//
//  FutureScreenTimeManager.swift
//  LockIn
//
//  Placeholder for the future Apple Screen Time integration. Intentionally
//  imports nothing from Apple Screen Time frameworks because the entitlement
//  has not been granted yet.
//
//  When the entitlement lands, this file will own the bridge between the
//  LockIn product (modes + setup) and Apple's Family Controls stack:
//
//    • FamilyControls / FamilyActivityPicker
//        Replaces our MockApp picker. Provides real, opaque app/category
//        tokens chosen by the user (we never see real app identities).
//
//    • DeviceActivity (DeviceActivityCenter + DeviceActivitySchedule)
//        Schedules background monitoring windows:
//          - Daily Limit mode  → an all-day daily schedule + a usage
//            threshold event for the selected apps.
//          - LockIn Mode       → a temporary schedule covering the focus
//            window + a much smaller slip-threshold event.
//
//    • DeviceActivityMonitorExtension
//        Companion app extension target. iOS wakes this extension when a
//        threshold is crossed; that's where we will trigger the LockIn
//        notification (using the same VoiceClip selection logic we already
//        have in NotificationManager).
//
//    • ManagedSettings (optional, later)
//        Could optionally shield/hide the offending apps after the alert
//        fires, gated by the cooldown.
//
//  For now this type exposes a tiny readiness flag so views can show
//  honest copy ("App monitoring connects after Apple Screen Time
//  permissions are enabled."). No real work is performed.
//

import Foundation

@MainActor
final class FutureScreenTimeManager {
    static let shared = FutureScreenTimeManager()

    /// `true` once the Family Controls entitlement is approved and we have
    /// authorization. For now this is always `false`.
    let isScreenTimeAvailable: Bool = false

    /// Honest, low-emphasis copy shown on screens that imply real monitoring.
    let pendingMessage: String =
        "App monitoring connects after Apple Screen Time permissions are enabled."

    private init() {}

    // Future surface (intentionally empty for now):
    // func requestAuthorization() async -> Bool { ... }
    // func startDailyLimitMonitoring(minutes: Int, appTokens: ...) { ... }
    // func startLockInSession(durationMinutes: Int, slipThresholdSeconds: Int, appTokens: ...) { ... }
    // func stopAll() { ... }
}
