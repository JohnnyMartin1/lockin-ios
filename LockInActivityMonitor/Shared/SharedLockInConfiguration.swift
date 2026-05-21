//
//  SharedLockInConfiguration.swift
//  LockInActivityMonitor (Device Activity Monitor extension target)
//
//  ⚠️ KEEP IN SYNC with LockIn/Shared/SharedLockInConfiguration.swift.
//

import Foundation

/// Snapshot of LockIn's current configuration shared between the main app and
/// the Device Activity Monitor extension via the App Group container.
struct SharedLockInConfiguration: Codable, Equatable {
    var modeType: String
    var selectedCharacterId: String
    var selectedClipIds: [String]
    var shuffleSayings: Bool
    var dailyLimitMinutes: Int
    var sessionLengthMinutes: Int
    var slipThresholdSeconds: Int
    var cooldownMinutes: Int
    var lastAlertFiredAt: Date?

    /// Pre-baked clip payloads so the extension never has to import or
    /// duplicate `VoiceLibrary`.
    var resolvedClips: [SharedVoiceClipPayload]

    static let `default` = SharedLockInConfiguration(
        modeType: "",
        selectedCharacterId: "",
        selectedClipIds: [],
        shuffleSayings: true,
        dailyLimitMinutes: 30,
        sessionLengthMinutes: 60,
        slipThresholdSeconds: 60,
        cooldownMinutes: 5,
        lastAlertFiredAt: nil,
        resolvedClips: []
    )

    var isValidForMonitoring: Bool {
        !selectedCharacterId.isEmpty && !selectedClipIds.isEmpty
    }
}

/// Compact clip payload the extension uses to fire a notification.
struct SharedVoiceClipPayload: Codable, Equatable, Hashable {
    let id: String
    let sayingTitle: String
    let notificationText: String
    let soundFileName: String
}
