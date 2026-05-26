//
//  SharedLockInConfiguration.swift
//  LockIn (main app target)
//
//  ⚠️ KEEP IN SYNC with LockInActivityMonitor/Shared/SharedLockInConfiguration.swift.
//

import Foundation

/// Snapshot of LockIn's current configuration shared between the main app and
/// the Device Activity Monitor extension via the App Group container.
///
/// The main app refreshes this snapshot whenever the user changes any setup
/// value (mode, limits, character, sayings, shuffle). The extension only
/// reads it.
///
/// Note: `FamilyActivitySelection` is intentionally **not** in this struct.
/// Phase A persists it under a separate key (`SharedKeys.familyActivitySelection`)
/// so the extension can decode it on its own with `PropertyListDecoder`.
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

    /// Resolved clip payloads pre-baked by the main app from `VoiceLibrary`
    /// so the extension never needs to import or duplicate voice data.
    var resolvedClips: [SharedVoiceClipPayload]

    /// Phase D — active LockIn Mode session window. Both fields are non-nil
    /// only while a LockIn session is being monitored by `DeviceActivityCenter`.
    /// The extension clears them in `intervalDidEnd(for:)`.
    var lockInSessionStartedAt: Date?
    var lockInSessionEndsAt: Date?

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
        resolvedClips: [],
        lockInSessionStartedAt: nil,
        lockInSessionEndsAt: nil
    )

    /// True if the snapshot has the minimum information the extension needs.
    /// `resolvedClips` is not required because the extension always has a
    /// safe fallback ("LOCK IN" + default sound) if clip resolution fails.
    var isValidForMonitoring: Bool {
        !selectedCharacterId.isEmpty && !selectedClipIds.isEmpty
    }
}

/// Compact clip payload the extension uses to fire a notification.
/// Mirrors the user-facing fields of `VoiceClip` so the extension can
/// schedule the right alert without depending on `VoiceLibrary`.
struct SharedVoiceClipPayload: Codable, Equatable, Hashable {
    let id: String
    let sayingTitle: String
    let notificationText: String
    let soundFileName: String
}
