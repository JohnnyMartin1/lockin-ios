//
//  SharedConfigurationStore.swift
//  LockInActivityMonitor (Device Activity Monitor extension target)
//
//  ⚠️ KEEP IN SYNC with LockIn/Shared/SharedConfigurationStore.swift.
//

import Foundation

/// Reads/writes the `SharedLockInConfiguration` JSON in the App Group container.
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

    func load() -> SharedLockInConfiguration {
        guard let defaults,
              let data = defaults.data(forKey: SharedLockInConstants.SharedKeys.configuration) else {
            return .default
        }
        do {
            return try decoder.decode(SharedLockInConfiguration.self, from: data)
        } catch {
            print("[LockInExt] SharedConfigurationStore: failed to decode configuration: \(error). Returning defaults.")
            return .default
        }
    }

    @discardableResult
    func save(_ configuration: SharedLockInConfiguration) -> Bool {
        guard let defaults else {
            print("[LockInExt] SharedConfigurationStore: App Group UserDefaults unavailable. Nothing saved.")
            return false
        }
        do {
            let data = try encoder.encode(configuration)
            defaults.set(data, forKey: SharedLockInConstants.SharedKeys.configuration)
            return true
        } catch {
            print("[LockInExt] SharedConfigurationStore: failed to encode configuration: \(error).")
            return false
        }
    }

    @discardableResult
    func markAlertFired(at date: Date = Date()) -> Bool {
        var current = load()
        current.lastAlertFiredAt = date
        return save(current)
    }
}
