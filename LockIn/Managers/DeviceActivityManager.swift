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
                return "Choose real apps with Screen Time access before starting monitoring."
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

    /// Reflects whether the LockIn Mode session activity is currently being
    /// monitored. Independent from Daily Limit — both can be on at once.
    @Published private(set) var isMonitoringLockInSession: Bool = false

    /// End date of the current LockIn Mode session, if any. Source of truth is
    /// the shared App Group snapshot so the extension and the app agree.
    @Published private(set) var lockInSessionEndsAt: Date?

    /// Most recent failure, set on the next call to `start...` or `stop...`.
    @Published private(set) var lastError: MonitoringError?

    /// Low-emphasis debug lines for StartLockInView after the last LockIn start attempt.
    @Published private(set) var lastLockInStartDebugLines: [String] = []

    /// Raw activity-name strings currently registered with `DeviceActivityCenter`.
    /// Updated by `debugCurrentActivities()`.
    @Published private(set) var registeredActivityNames: [String] = []

    /// True while the diagnostic debug-wake activity is registered. Exposed for the
    /// Developer Debug UI; the app should never depend on this for product behavior.
    @Published private(set) var isMonitoringDebugWake: Bool = false

    private let center = DeviceActivityCenter()

    private let dailyActivityName     = DeviceActivityName(SharedLockInConstants.ActivityName.dailyLimit)
    private let dailyEventName        = DeviceActivityEvent.Name(SharedLockInConstants.EventName.dailyLimitReached)
    private let lockInActivityName    = DeviceActivityName(SharedLockInConstants.ActivityName.lockInSession)
    private let lockInSlipEventName   = DeviceActivityEvent.Name(SharedLockInConstants.EventName.lockInSlipThresholdReached)
    private let debugWakeActivityName = DeviceActivityName(SharedLockInConstants.ActivityName.debugWake)

    private init() {
        refreshStatus()
        debugCurrentActivities()
    }

    // MARK: - Logging helper

    /// Mirrors a line to both `print` and the persistent App Group log store so
    /// it shows up in StartLockInView's Developer Debug panel.
    private func log(_ message: String) {
        print("[LockIn] \(message)")
        ScreenTimeDebugLogStore.append(.app, message)
    }

    // MARK: - Status

    /// Re-reads the OS-tracked list of activities and the App Group session
    /// window. Call on view appear so the UI recovers after relaunch
    /// (monitoring state persists across launches).
    func refreshStatus() {
        let activities = center.activities
        isMonitoringDailyLimit    = activities.contains(dailyActivityName)
        isMonitoringLockInSession = activities.contains(lockInActivityName)
        isMonitoringDebugWake     = activities.contains(debugWakeActivityName)

        let stored = SharedConfigurationStore.shared.load()
        if isMonitoringLockInSession {
            lockInSessionEndsAt = stored.lockInSessionEndsAt
        } else {
            lockInSessionEndsAt = nil
        }
    }

    // MARK: - Diagnostics

    /// Reads `DeviceActivityCenter.activities` and publishes the list so
    /// Developer Debug can render it. Also writes a summary line to the App
    /// Group debug log for after-the-fact inspection.
    func debugCurrentActivities() {
        let names = center.activities.map(\.rawValue)
        registeredActivityNames = names

        let hasDaily  = names.contains(SharedLockInConstants.ActivityName.dailyLimit)
        let hasLockIn = names.contains(SharedLockInConstants.ActivityName.lockInSession)
        let hasWake   = names.contains(SharedLockInConstants.ActivityName.debugWake)
        log("debugCurrentActivities count=\(names.count) "
            + "daily=\(hasDaily) lockIn=\(hasLockIn) debugWake=\(hasWake) "
            + "names=\(names)")
    }

    // MARK: - Test Extension Wakeup (interval-only, no usage events)

    /// Registers a short, non-repeating DeviceActivity *interval* with no usage
    /// events. The only thing this triggers is `intervalDidStart` shortly
    /// after, and `intervalDidEnd` 2 minutes later. If those callbacks fire,
    /// the extension is reachable and the system is configured correctly —
    /// the issue is elsewhere (selection tokens or event threshold).
    /// If they don't fire, the extension isn't being woken at all.
    @discardableResult
    func startDebugWakeMonitoring() -> Result<Void, MonitoringError> {
        log("Test Extension Wakeup requested")

        // Reset any prior wake schedule.
        if center.activities.contains(debugWakeActivityName) {
            center.stopMonitoring([debugWakeActivityName])
            log("Stopped previous debugWake activity before restart.")
        }

        let calendar = Calendar.current
        let now      = Date()
        let start    = now.addingTimeInterval(-30)             // backdated so interval is active immediately
        let end      = now.addingTimeInterval(2 * 60)          // 2 minute window

        let startComponents = calendar.dateComponents(
            [.year, .month, .day, .hour, .minute, .second], from: start
        )
        let endComponents = calendar.dateComponents(
            [.hour, .minute, .second], from: end
        )

        let schedule = DeviceActivitySchedule(
            intervalStart: startComponents,
            intervalEnd:   endComponents,
            repeats:       false
        )

        log("debugWake activity=\(debugWakeActivityName.rawValue)")
        log("debugWake schedule intervalStart=\(Self.describeDateComponents(startComponents))")
        log("debugWake schedule intervalEnd=\(Self.describeDateComponents(endComponents)) repeats=false")
        log("debugWake events=[:] (interval-only, no usage events)")

        do {
            try center.startMonitoring(debugWakeActivityName, during: schedule)
            isMonitoringDebugWake = true
            log("debugWake startMonitoring SUCCEEDED — expect [ext] intervalDidStart within ~30s.")
            debugCurrentActivities()
            return .success(())
        } catch {
            let message = (error as NSError).localizedDescription
            log("debugWake startMonitoring FAILED: \(message.isEmpty ? "\(error)" : message)")
            refreshStatus()
            return .failure(.underlying(message.isEmpty ? "\(error)" : message))
        }
    }

    func stopDebugWakeMonitoring() {
        center.stopMonitoring([debugWakeActivityName])
        isMonitoringDebugWake = false
        log("debugWake stopped.")
        debugCurrentActivities()
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
            log("DeviceActivity started: dailyLimit "
                + "threshold=\(minutes)m "
                + "apps=\(selection.applicationTokens.count) "
                + "categories=\(selection.categoryTokens.count) "
                + "webs=\(selection.webDomainTokens.count)")
            debugCurrentActivities()
            return .success(())
        } catch {
            let message = (error as NSError).localizedDescription
            let err: MonitoringError = .underlying(message.isEmpty ? "\(error)" : message)
            lastError = err
            // Reflect the OS truth — if startMonitoring threw, we are not monitoring.
            refreshStatus()
            log("DeviceActivity start failed: \(error)")
            return .failure(err)
        }
    }

    // MARK: - Daily Limit stop

    /// Stops Daily Limit monitoring. Idempotent — calling when not monitoring
    /// is a no-op. Does not touch the LockIn Mode session.
    func stopDailyLimitMonitoring() {
        center.stopMonitoring([dailyActivityName])
        isMonitoringDailyLimit = false
        lastError = nil
        log("DeviceActivity stopped: dailyLimit")
        debugCurrentActivities()
    }

    // MARK: - LockIn Mode start

    /// Starts a LockIn Mode session monitored against the slip threshold.
    /// Independent from Daily Limit — calling this never affects daily limit
    /// monitoring or vice versa.
    @discardableResult
    func startLockInSessionMonitoring(
        selection: FamilyActivitySelection,
        sessionLengthMinutes: Int,
        slipThresholdSeconds: Int,
        isAuthorized: Bool
    ) -> Result<Void, MonitoringError> {

        log("Starting LockIn Mode monitoring")

        guard isAuthorized else {
            let err: MonitoringError = .notAuthorized
            lastError = err
            lastLockInStartDebugLines = ["Screen Time not authorized."]
            log("LockIn start aborted: not authorized.")
            return .failure(err)
        }

        // Always use the App Group copy so tokens match the saved picker state.
        FamilySelectionStore.shared.reloadFromAppGroup()
        let activeSelection = FamilySelectionStore.shared.selection

        let appCount = activeSelection.applicationTokens.count
        let catCount = activeSelection.categoryTokens.count
        let webCount = activeSelection.webDomainTokens.count

        log("FamilyActivitySelection — apps=\(appCount) categories=\(catCount) webs=\(webCount)")

        let hasAny = appCount > 0 || catCount > 0 || webCount > 0
        guard hasAny else {
            let err: MonitoringError = .emptySelection
            lastError = err
            lastLockInStartDebugLines = [
                "No real apps selected.",
                "Choose real apps with Screen Time access before starting LockIn Mode."
            ]
            log("LockIn start aborted: FamilyActivitySelection is empty.")
            return .failure(err)
        }

        let sessionMinutes = max(1, sessionLengthMinutes)
        let slipSeconds    = max(1, slipThresholdSeconds)
        let threshold      = Self.slipThresholdDateComponents(seconds: slipSeconds)

        // Sync + read-back verify App Group config for the extension.
        SetupSyncCoordinator.syncCurrentSetupToSharedStore()
        let readBack = SharedConfigurationStore.shared.load()
        let sharedOK = readBack.isValidForMonitoring && !readBack.resolvedClips.isEmpty
        log("SharedLockInConfiguration read-back: ok=\(sharedOK) "
            + "character=\(readBack.selectedCharacterId) "
            + "clipIds=\(readBack.selectedClipIds.count) "
            + "resolvedClips=\(readBack.resolvedClips.count) "
            + "shuffle=\(readBack.shuffleSayings) "
            + "cooldownMin=\(readBack.cooldownMinutes)")
        if !sharedOK {
            log("WARNING: shared config invalid for monitoring — extension may use fallback alert text.")
        }

        if slipSeconds < 60 {
            log("WARNING: slip threshold is \(slipSeconds)s. iOS often does not fire usage events for thresholds under 1 minute — try 1-minute slip for testing.")
        }

        // Reset any prior LockIn session schedule before registering a new one.
        if center.activities.contains(lockInActivityName) {
            log("Stopping existing lockInSession activity before restart.")
            center.stopMonitoring([lockInActivityName])
        }

        let calendar = Calendar.current
        let (schedule, sessionStart, sessionEnd) = Self.makeLockInSessionSchedule(
            sessionLengthMinutes: sessionMinutes,
            calendar: calendar
        )

        let startDesc  = Self.describeDateComponents(schedule.intervalStart)
        let endDesc    = Self.describeDateComponents(schedule.intervalEnd)
        let threshDesc = Self.describeDateComponents(threshold)

        log("activity=\(lockInActivityName.rawValue)")
        log("event=\(lockInSlipEventName.rawValue)")
        log("sessionLengthMinutes=\(sessionMinutes)")
        log("slipThresholdSeconds=\(slipSeconds) → threshold \(threshDesc)")
        log("schedule intervalStart=\(startDesc)")
        log("schedule intervalEnd=\(endDesc) repeats=false")
        log("includesPastActivity=false")
        log("session window \(sessionStart) → \(sessionEnd)")

        let event = DeviceActivityEvent(
            applications: activeSelection.applicationTokens,
            categories:   activeSelection.categoryTokens,
            webDomains:   activeSelection.webDomainTokens,
            threshold:    threshold,
            includesPastActivity: false
        )

        do {
            try center.startMonitoring(
                lockInActivityName,
                during: schedule,
                events: [lockInSlipEventName: event]
            )

            var stored = SharedConfigurationStore.shared.load()
            stored.lockInSessionStartedAt = sessionStart
            stored.lockInSessionEndsAt   = sessionEnd
            SharedConfigurationStore.shared.save(stored)

            isMonitoringLockInSession = true
            lockInSessionEndsAt       = sessionEnd
            lastError = nil

            log("DeviceActivityCenter.startMonitoring SUCCEEDED")
            debugCurrentActivities()

            lastLockInStartDebugLines = [
                "Monitoring started",
                "Apps \(appCount) · categories \(catCount) · sites \(webCount)",
                "Session \(sessionMinutes) min · slip \(slipSeconds)s (\(threshDesc))",
                "Activity \(lockInActivityName.rawValue)",
                "Shared config \(sharedOK ? "OK" : "missing voice data")"
            ]

            return .success(())
        } catch {
            let message = (error as NSError).localizedDescription
            let err: MonitoringError = .underlying(message.isEmpty ? "\(error)" : message)
            lastError = err
            refreshStatus()
            lastLockInStartDebugLines = ["Start failed: \(message.isEmpty ? "\(error)" : message)"]
            log("DeviceActivityCenter.startMonitoring FAILED: \(error)")
            return .failure(err)
        }
    }

    // MARK: - LockIn Mode stop

    /// Stops the LockIn Mode session. Idempotent; never touches Daily Limit
    /// monitoring. Clears the App Group session window so the UI matches.
    func stopLockInSessionMonitoring() {
        center.stopMonitoring([lockInActivityName])

        var stored = SharedConfigurationStore.shared.load()
        stored.lockInSessionStartedAt = nil
        stored.lockInSessionEndsAt   = nil
        SharedConfigurationStore.shared.save(stored)

        isMonitoringLockInSession = false
        lockInSessionEndsAt       = nil
        lastError = nil
        log("DeviceActivity stopped: lockInSession")
        lastLockInStartDebugLines = []
        debugCurrentActivities()
    }

    // MARK: - Diagnostic log control

    /// Clears the App Group debug log entries. Exposed for Developer Debug only.
    func clearDebugLog() {
        ScreenTimeDebugLogStore.clear()
        log("Debug log cleared.")
    }
}

// TODO: If DeviceActivity continues to be unreliable for short thresholds
// (< 60s), consider a future opt-in fallback that uses a
// `UNTimeIntervalNotificationTrigger` from the main app for *preview only*
// — never for real monitoring. The real product behavior must remain
// DeviceActivity-driven so it works in the background.

// MARK: - LockIn schedule / threshold helpers

private extension DeviceActivityManager {

    /// Maps stored slip seconds to `DateComponents` without treating seconds as minutes.
    /// 30 → second:30, 60 → minute:1, 300 → minute:5.
    static func slipThresholdDateComponents(seconds: Int) -> DateComponents {
        let s = max(1, seconds)
        if s >= 60, s % 60 == 0 {
            return DateComponents(minute: s / 60)
        }
        return DateComponents(second: s)
    }


    /// Builds a one-shot schedule anchored to *today* with the interval already active.
    ///
    /// Apple DTS guidance: for same-calendar-day windows, include `.day` (and full date)
    /// on `intervalStart` but omit `.day` from `intervalEnd` — only hour/minute/second.
    /// Using hour/minute alone on both ends often prevents `intervalDidStart` from firing.
    static func makeLockInSessionSchedule(
        sessionLengthMinutes: Int,
        calendar: Calendar = .current
    ) -> (schedule: DeviceActivitySchedule, sessionStart: Date, sessionEnd: Date) {
        let now = Date()
        // Start slightly in the past so the monitoring window is active immediately.
        let sessionStart = now.addingTimeInterval(-30)
        let sessionEnd = now.addingTimeInterval(TimeInterval(max(1, sessionLengthMinutes) * 60))

        let startComponents = calendar.dateComponents(
            [.year, .month, .day, .hour, .minute, .second],
            from: sessionStart
        )

        let sameCalendarDay = calendar.isDate(sessionStart, inSameDayAs: sessionEnd)
        let endComponents: DateComponents
        if sameCalendarDay {
            endComponents = calendar.dateComponents(
                [.hour, .minute, .second],
                from: sessionEnd
            )
        } else {
            // Session crosses midnight — include full date on end as well.
            endComponents = calendar.dateComponents(
                [.year, .month, .day, .hour, .minute, .second],
                from: sessionEnd
            )
            print("[LockIn] WARNING: LockIn session crosses midnight — schedule may be less reliable.")
        }

        let schedule = DeviceActivitySchedule(
            intervalStart: startComponents,
            intervalEnd: endComponents,
            repeats: false
        )
        return (schedule, sessionStart, sessionEnd)
    }

    static func describeDateComponents(_ components: DateComponents) -> String {
        var parts: [String] = []
        if let y = components.year   { parts.append("y=\(y)") }
        if let m = components.month  { parts.append("mo=\(m)") }
        if let d = components.day    { parts.append("d=\(d)") }
        if let h = components.hour   { parts.append("h=\(h)") }
        if let min = components.minute { parts.append("min=\(min)") }
        if let s = components.second { parts.append("s=\(s)") }
        return parts.isEmpty ? "(empty)" : parts.joined(separator: " ")
    }
}
