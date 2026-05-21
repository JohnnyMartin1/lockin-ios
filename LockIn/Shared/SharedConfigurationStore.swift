//
//  SharedConfigurationStore.swift
//  LockIn (main app target)
//
//  ⚠️ KEEP IN SYNC with LockInActivityMonitor/Shared/SharedConfigurationStore.swift.
//

import Foundation

/// Reads/writes the `SharedLockInConfiguration` JSON in the App Group
/// container. Safe to use from both the main app and the extension.
final class SharedConfigurationStore {

    static let shared = SharedConfigurationStore()

    private let defaults: UserDefaults?
    private let encoder: JSONEncoder
    private let decoder: JSONDecoder

    init(defaults: UserDefaults? = UserDefaults(suiteName: SharedLockInConstants.appGroupIdentifier)) {
        self.defaults = defaults
        let enc = JSONEncoder()
        enc.dateEncodingStrategy = .iso8601
        self.encoder = enc
        let dec = JSONDecoder()
        dec.dateDecodingStrategy = .iso8601
        self.decoder = dec
    }

    // MARK: - Load

    /// Returns the saved configuration if any, otherwise `.default`.
    /// Never throws — invalid blobs degrade to defaults with a developer log.
    func load() -> SharedLockInConfiguration {
        guard let defaults,
              let data = defaults.data(forKey: SharedLockInConstants.SharedKeys.configuration) else {
            return .default
        }
        do {
            return try decoder.decode(SharedLockInConfiguration.self, from: data)
        } catch {
            print("[LockIn] SharedConfigurationStore: failed to decode configuration: \(error). Returning defaults.")
            return .default
        }
    }

    // MARK: - Save

    @discardableResult
    func save(_ configuration: SharedLockInConfiguration) -> Bool {
        guard let defaults else {
            print("[LockIn] SharedConfigurationStore: App Group UserDefaults unavailable. Configuration not persisted.")
            return false
        }
        do {
            let data = try encoder.encode(configuration)
            defaults.set(data, forKey: SharedLockInConstants.SharedKeys.configuration)
            return true
        } catch {
            print("[LockIn] SharedConfigurationStore: failed to encode configuration: \(error).")
            return false
        }
    }

    // MARK: - Cooldown bookkeeping (called by the extension)

    @discardableResult
    func markAlertFired(at date: Date = Date()) -> Bool {
        var current = load()
        current.lastAlertFiredAt = date
        return save(current)
    }
}
