//
//  DeviceActivityManager.swift
//  LockIn (main app target only)
//
//  Phase C: starts and stops Daily Limit monitoring through
//  `DeviceActivityCenter`. The Device Activity Monitor extension (Phase B)
//  receives the threshold callback and fires the chosen voice notification.
//
//  Phase C scope only — Daily Limit. LockIn Mode (slip threshold) and
//  ManagedSettings shielding land in later phases.
//

import Combine
import DeviceActivity
import FamilyControls
import Foundation

@MainActor
final class DeviceActivityManager: ObservableObject {

    /// User-facing error surface. Always returned as a value so callers can
    /// render simple status copy without dealing with NSError details.
    enum MonitoringError: LocalizedError, Equatable {
        case notAuthorized
        case emptySelection
        case nothingToMonitor(String)
        case underlying(String)

        var errorDescription: String? {
            switch self {
            case .notAuthorized:
                return "Screen Time access isn't enabled yet. Open the Apps screen to enable it."
            case .emptySelection:
                return "Choose real apps with Screen Time access to start Daily Limit monitoring."
            case .nothingToMonitor(let message):
                return message
            case .underlying(let message):
                return message
            }
        }
    }

    static let shared = DeviceActivityManager()

    /// Reflects whether the daily limit activity is currently being monitored
    /// by `DeviceActivityCenter`. Refresh by calling `refreshStatus()`.
    @Published private(set) var isMonitoringDailyLimit: Bool = false

    /// Most recent failure, set on the next call to `start...` or `stop...`.
    @Published private(set) var lastError: MonitoringError?

    private let center = DeviceActivityCenter()

    private let dailyActivityName = DeviceActivityName(SharedLockInConstants.ActivityName.dailyLimit)
    private let dailyEventName    = DeviceActivityEvent.Name(SharedLockInConstants.EventName.dailyLimitReached)

    private init() {
        refreshStatus()
    }

    // MARK: - Status

    /// Re-reads the OS-tracked list of activities. Call on view appear so the
    /// UI recovers after relaunch (monitoring state persists across launches).
    func refreshStatus() {
        isMonitoringDailyLimit = center.activities.contains(dailyActivityName)
    }

    // MARK: - Daily Limit start

    /// Starts Daily Limit monitoring for the given selection. Returns `.success`
    /// on a successful `DeviceActivityCenter.startMonitoring(...)`.
    @discardableResult
    func startDailyLimitMonitoring(
        selection: FamilyActivitySelection,
        dailyLimitMinutes: Int,
        isAuthorized: Bool
    ) -> Result<Void, MonitoringError> {

        guard isAuthorized else {
            let err: MonitoringError = .notAuthorized
            lastError = err
            return .failure(err)
        }

        let hasAny = !selection.applicationTokens.isEmpty
            || !selection.categoryTokens.isEmpty
            || !selection.webDomainTokens.isEmpty
        guard hasAny else {
            let err: MonitoringError = .emptySelection
            lastError = err
            return .failure(err)
        }

        let minutes = max(1, dailyLimitMinutes)

        // Refresh the shared snapshot so the extension picks up the latest
        // mode / character / clips / shuffle / cooldown right before any
        // threshold event can fire.
        SetupSyncCoordinator.syncCurrentSetupToSharedStore()

        // All-day repeating schedule. iOS treats `intervalEnd` exclusively, so
        // (00:00, 23:59) covers the whole day and `repeats: true` resets the
        // usage counter every midnight.
        let schedule = DeviceActivitySchedule(
            intervalStart: DateComponents(hour: 0, minute: 0),
            intervalEnd:   DateComponents(hour: 23, minute: 59),
            repeats: true
        )

        let event = DeviceActivityEvent(
            applications: selection.applicationTokens,
            categories:   selection.categoryTokens,
            webDomains:   selection.webDomainTokens,
            threshold:    DateComponents(minute: minutes)
        )

        do {
            try center.startMonitoring(
                dailyActivityName,
                during: schedule,
                events: [dailyEventName: event]
            )
            isMonitoringDailyLimit = true
            lastError = nil
            print("[LockIn] DeviceActivity started: dailyLimit "
                  + "threshold=\(minutes)m "
                  + "apps=\(selection.applicationTokens.count) "
                  + "categories=\(selection.categoryTokens.count) "
                  + "webs=\(selection.webDomainTokens.count)")
            return .success(())
        } catch {
            let message = (error as NSError).localizedDescription
            let err: MonitoringError = .underlying(message.isEmpty ? "\(error)" : message)
            lastError = err
            // Reflect the OS truth — if startMonitoring threw, we are not monitoring.
            refreshStatus()
            print("[LockIn] DeviceActivity start failed: \(error)")
            return .failure(err)
        }
    }

    // MARK: - Daily Limit stop

    /// Stops Daily Limit monitoring. Idempotent — calling when not monitoring
    /// is a no-op.
    func stopDailyLimitMonitoring() {
        center.stopMonitoring([dailyActivityName])
        isMonitoringDailyLimit = false
        lastError = nil
        print("[LockIn] DeviceActivity stopped: dailyLimit")
    }
}
