//
//  LockInMode.swift
//  LockIn
//
//  Product modes, app groups, and the local AppStorage keys that describe a
//  configured LockIn setup. Source of truth for the new mode-driven product.
//

import Foundation

// MARK: - Mode type

enum LockInModeType: String, CaseIterable, Identifiable {
    case dailyLimit
    case lockInSession

    var id: String { rawValue }

    var displayName: String {
        switch self {
        case .dailyLimit:    return "Daily Limit"
        case .lockInSession: return "LockIn Mode"
        }
    }

    var tagline: String {
        switch self {
        case .dailyLimit:
            return "Get alerted when selected apps pass your daily limit."
        case .lockInSession:
            return "Start a focus window and get alerted if you slip into selected apps."
        }
    }

    var systemImage: String {
        switch self {
        case .dailyLimit:    return "hourglass"
        case .lockInSession: return "scope"
        }
    }
}

// MARK: - App groups

struct LockInAppGroup: Identifiable, Hashable {
    let id: String
    let name: String
    let appIDs: [String]
    let systemImage: String
}

extension LockInAppGroup {
    static let presets: [LockInAppGroup] = [
        LockInAppGroup(
            id: "doomscrolling",
            name: "Doomscrolling",
            appIDs: ["instagram", "tiktok", "x", "reddit"],
            systemImage: "iphone.gen3.radiowaves.left.and.right"
        ),
        LockInAppGroup(
            id: "video",
            name: "Video",
            appIDs: ["youtube", "tiktok"],
            systemImage: "play.rectangle.fill"
        ),
        LockInAppGroup(
            id: "social",
            name: "Social",
            appIDs: ["instagram", "snapchat", "facebook", "x"],
            systemImage: "person.2.fill"
        )
    ]

    static func group(withID id: String) -> LockInAppGroup? {
        presets.first { $0.id == id }
    }

    /// Returns the preset whose `appIDs` exactly match the given (unordered) set, or nil.
    static func match(forSelectedAppIDs ids: [String]) -> LockInAppGroup? {
        let set = Set(ids)
        return presets.first { Set($0.appIDs) == set }
    }
}

// MARK: - Storage keys

enum LockInSetupKeys {
    static let modeType              = "lockin.setup.modeType"              // raw value of LockInModeType
    static let appGroupID            = "lockin.setup.appGroupID"            // empty when none
    static let dailyLimitMinutes     = "lockin.setup.dailyLimitMinutes"
    static let sessionLengthMinutes  = "lockin.setup.sessionLengthMinutes"
    static let slipThresholdSeconds  = "lockin.setup.slipThresholdSeconds"
    static let cooldownMinutes       = "lockin.setup.cooldownMinutes"
    static let randomizeSayings      = "lockin.setup.randomizeSayings"
}

enum LockInDefaults {
    static let dailyLimitMinutes    = 30
    static let sessionLengthMinutes = 60     // 1 hour
    static let slipThresholdSeconds = 60     // 1 minute
    static let cooldownMinutes      = 5
    static let randomizeSayings     = true
}

// MARK: - Option lists

enum LockInOptions {
    /// Daily Limit options, in minutes (per spec).
    static let dailyLimitMinutes:    [Int] = [5, 10, 15, 30, 60]
    /// LockIn Mode session lengths, in minutes (per spec).
    static let sessionLengthMinutes: [Int] = [30, 60, 120, 240]
    /// LockIn Mode slip thresholds, in seconds (per spec: 30 sec, 1 min, 5 min).
    static let slipThresholdSeconds: [Int] = [30, 60, 300]
}

// MARK: - Display formatting

enum LimitFormatter {
    static func minutes(_ m: Int) -> String {
        if m >= 60, m % 60 == 0 {
            let h = m / 60
            return h == 1 ? "1 hour" : "\(h) hours"
        }
        return m == 1 ? "1 minute" : "\(m) minutes"
    }

    /// Short label: "5m", "1h", "30s".
    static func shortMinutes(_ m: Int) -> String {
        if m >= 60, m % 60 == 0 {
            return "\(m / 60)h"
        }
        return "\(m)m"
    }

    static func seconds(_ s: Int) -> String {
        if s >= 60, s % 60 == 0 {
            return minutes(s / 60)
        }
        return s == 1 ? "1 second" : "\(s) seconds"
    }

    static func shortSeconds(_ s: Int) -> String {
        if s >= 60, s % 60 == 0 {
            return shortMinutes(s / 60)
        }
        return "\(s)s"
    }
}
