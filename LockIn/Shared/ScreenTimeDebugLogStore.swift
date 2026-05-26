//
//  ScreenTimeDebugLogStore.swift
//  LockIn (main app target)
//
//  ⚠️ KEEP IN SYNC with LockInActivityMonitor/Shared/ScreenTimeDebugLogStore.swift.
//
//  Persistent diagnostic log shared between the main app and the Device
//  Activity Monitor extension via the App Group container. Extensions are
//  hard to attach to in Xcode, so we mirror their important events here so
//  the main app can render them in Developer Debug.
//
//  Capped to the most recent ~100 entries (FIFO). Writes happen via UserDefaults
//  inside the App Group — reasonably fast and crash-safe.
//

import Foundation

enum ScreenTimeDebugLogStore {

    /// Tag used in the log line so app vs. extension entries are obvious.
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

    // MARK: - Write

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

    // MARK: - Read

    static func entries() -> [String] {
        defaults?.stringArray(forKey: SharedLockInConstants.SharedKeys.debugLog) ?? []
    }

    /// Returns the last `n` entries (most recent last).
    static func tail(_ n: Int) -> [String] {
        let all = entries()
        if all.count <= n { return all }
        return Array(all.suffix(n))
    }

    static func clear() {
        defaults?.removeObject(forKey: SharedLockInConstants.SharedKeys.debugLog)
    }
}
