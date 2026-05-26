//
//  SharedLockInConstants.swift
//  LockInActivityMonitor (Device Activity Monitor extension target)
//
//  ⚠️ KEEP IN SYNC with LockIn/Shared/SharedLockInConstants.swift.
//  This file is intentionally duplicated in the main app target because Xcode
//  synchronized groups don't share files across targets. Both copies must
//  declare the same symbols. If you change one, change the other.
//

import Foundation

/// Constants shared between the main app and the Device Activity Monitor extension.
enum SharedLockInConstants {

    /// App Group container shared with the main app.
    static let appGroupIdentifier = "group.com.JohnMartin.LockInapp"

    /// DeviceActivity activity names.
    enum ActivityName {
        static let dailyLimit    = "com.JohnMartin.LockInapp.activity.dailyLimit"
        static let lockInSession = "com.JohnMartin.LockInapp.activity.lockInSession"
        /// Diagnostic activity registered by the main app to test extension wakeup.
        static let debugWake     = "com.JohnMartin.LockInapp.activity.debugWake"
    }

    /// DeviceActivity event names within those activities.
    enum EventName {
        static let dailyLimitReached          = "com.JohnMartin.LockInapp.event.dailyLimitReached"
        static let lockInSlipThresholdReached = "com.JohnMartin.LockInapp.event.lockInSlipThresholdReached"
    }

    /// Local notification request identifiers used by the extension when it
    /// fires alerts.
    enum NotificationIdentifier {
        static let dailyLimit    = "lockin.notification.dailyLimit"
        static let lockInSession = "lockin.notification.lockInSession"
    }

    /// Keys for values persisted into `UserDefaults(suiteName: appGroupIdentifier)`.
    enum SharedKeys {
        /// Single JSON blob holding the full `SharedLockInConfiguration`.
        static let configuration             = "lockin.shared.configuration.v1"
        /// `FamilyActivitySelection` blob written by `FamilySelectionStore`.
        static let familyActivitySelection   = "lockin.familyActivitySelection.v1"
        /// Rolling array of human-readable debug lines written by both the
        /// main app and the extension. See `ScreenTimeDebugLogStore`.
        static let debugLog                  = "lockin.shared.debugLog.v1"
    }
}
