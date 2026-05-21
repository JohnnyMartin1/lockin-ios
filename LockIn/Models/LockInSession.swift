//
//  LockInSession.swift
//  LockIn
//
//  Lightweight value type that describes a configured/running LockIn session.
//  Persistence stays in AppStorage — this struct is just a derived snapshot.
//

import Foundation

struct LockInSession: Equatable {
    enum Mode: String, Codable {
        case manual
        case daily
    }

    var selectedMockApps: [String]
    var selectedLimitMinutes: Int
    var selectedCharacterId: String
    var selectedClipId: String
    var mode: Mode
    var isActive: Bool
    var createdAt: Date
}

extension LockInSession {
    /// The persisted (configured) session derived from current AppStorage state.
    /// The active session is tracked separately via `SessionKeys.scheduledFireDate`.
    static func configured(
        apps: [String],
        limitMinutes: Int,
        characterId: String,
        clipId: String,
        mode: Mode = .manual
    ) -> LockInSession {
        LockInSession(
            selectedMockApps: apps,
            selectedLimitMinutes: limitMinutes,
            selectedCharacterId: characterId,
            selectedClipId: clipId,
            mode: mode,
            isActive: false,
            createdAt: Date()
        )
    }
}

/// AppStorage keys for the running session state. The rest of the LockIn
/// configuration (apps, limit, voice) already has its own keys.
enum SessionKeys {
    static let mode = "lockin.session.mode"
    /// Unix epoch (seconds) when the currently scheduled LockIn alert is
    /// expected to fire. `0` means no active session.
    static let scheduledFireDate = "lockin.session.scheduledFireDate"
    /// Identifier of the clip that was scheduled.
    static let scheduledClipId = "lockin.session.scheduledClipId"
}
