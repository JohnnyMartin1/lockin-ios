//
//  ScreenTimeDebugLogStore.swift
//  LockInActivityMonitor (Device Activity Monitor extension target)
//
//  ⚠️ KEEP IN SYNC with LockIn/Shared/ScreenTimeDebugLogStore.swift.
//

import Foundation

enum ScreenTimeDebugLogStore {

    enum Source: String {
        case app = "app"
        case ext = "extension"
    }

    private static let maxEntries = 100

    private static var defaults: UserDefaults? {
        UserDefaults(suiteName: SharedLockInConstants.appGroupIdentifier)
    }

    private static let timestampFormatter: DateFormatter = {
        let f = DateFormatter()
        f.dateFormat = "HH:mm:ss.SSS"
        f.locale = Locale(identifier: "en_US_POSIX")
        return f
    }()

    static func append(_ source: Source, _ message: String) {
        guard let defaults else { return }
        let ts = timestampFormatter.string(from: Date())
        let line = "\(ts) [\(source.rawValue)] \(message)"
        var entries = defaults.stringArray(forKey: SharedLockInConstants.SharedKeys.debugLog) ?? []
        entries.append(line)
        if entries.count > maxEntries {
            entries.removeFirst(entries.count - maxEntries)
        }
        defaults.set(entries, forKey: SharedLockInConstants.SharedKeys.debugLog)
    }

    static func entries() -> [String] {
        defaults?.stringArray(forKey: SharedLockInConstants.SharedKeys.debugLog) ?? []
    }

    static func tail(_ n: Int) -> [String] {
        let all = entries()
        if all.count <= n { return all }
        return Array(all.suffix(n))
    }

    static func clear() {
        defaults?.removeObject(forKey: SharedLockInConstants.SharedKeys.debugLog)
    }
}
