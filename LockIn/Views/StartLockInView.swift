//
//  StartLockInView.swift
//  LockIn
//
//  Mode-aware screen. Daily Limit mode now starts real DeviceActivity
//  monitoring (Phase C). LockIn Mode is still a preview placeholder until
//  Phase D wires slip-threshold monitoring.
//

import SwiftUI
import UserNotifications

struct StartLockInView: View {
    @StateObject private var notificationManager = NotificationManager.shared
    @Environment(\.dismiss) private var dismiss

    @AppStorage(LockInSetupKeys.modeType)             private var modeRaw: String           = ""
    @AppStorage(LockInSetupKeys.dailyLimitMinutes)    private var dailyLimitMinutes: Int    = LockInDefaults.dailyLimitMinutes
    @AppStorage(LockInSetupKeys.sessionLengthMinutes) private var sessionLengthMinutes: Int = LockInDefaults.sessionLengthMinutes
    @AppStorage(LockInSetupKeys.slipThresholdSeconds) private var slipThresholdSeconds: Int = LockInDefaults.slipThresholdSeconds
    @AppStorage(LockInSetupKeys.randomizeSayings)     private var shuffleSayings: Bool      = LockInDefaults.randomizeSayings
    @AppStorage(SelectedAppsKeys.ids)                 private var savedAppIDsRaw: String    = ""
    @AppStorage(SelectedVoiceKeys.characterId)        private var savedCharacterID: String  = ""
    @AppStorage(SelectedVoiceKeys.clipIds)            private var savedClipIDsRaw: String   = ""
    @AppStorage(SessionKeys.scheduledFireDate)        private var scheduledFireEpoch: Double = 0

    @StateObject private var familyStore   = FamilySelectionStore.shared
    @StateObject private var screenTime    = ScreenTimeManager.shared
    @StateObject private var dailyMonitor  = DeviceActivityManager.shared

    @State private var statusMessage: String?
    @State private var hasRequestedPermission = false
    @State private var hasPendingLockIn = false
    @State private var showDebugSection = false
    @State private var debugLogLines: [String] = []
    @State private var debugLogRefreshTrigger = 0

    // MARK: - Derived

    private var mode: LockInModeType? { LockInModeType(rawValue: modeRaw) }

    private var selectedCharacter: VoiceCharacter {
        VoiceLibrary.character(withID: savedCharacterID) ?? VoiceLibrary.defaultCharacter
    }

    private var selectedClips: [VoiceClip] {
        let ids = Set(SelectedClipsStorage.decode(savedClipIDsRaw))
        let fromCharacter = selectedCharacter.clips.filter { ids.contains($0.id) }
        if !fromCharacter.isEmpty { return fromCharacter }
        // Fallback so a preview always has something to play.
        return [VoiceLibrary.firstClip(forCharacter: selectedCharacter.id) ?? VoiceLibrary.defaultClip]
    }

    private var selectedAppCount: Int {
        SelectedAppsStorage.decode(savedAppIDsRaw).count
    }

    private var appsValueLabel: String {
        if familyStore.hasAnySelection {
            return "Apps selected"
        }
        switch selectedAppCount {
        case 0: return "No apps selected"
        default: return "Preview apps \u{00B7} \(selectedAppCount)"
        }
    }

    private var sayingsLabel: String {
        let n = selectedClips.count
        if n <= 1 { return selectedClips.first?.sayingTitle ?? "—" }
        return shuffleSayings ? "\(n) (shuffle)" : "\(n)"
    }

    private var scheduledFireDate: Date? {
        scheduledFireEpoch > 0 ? Date(timeIntervalSince1970: scheduledFireEpoch) : nil
    }

    private var previewButtonTitle: String {
        switch mode {
        case .some(.dailyLimit):    return "Preview Alert"
        case .some(.lockInSession): return "Start Preview Session"
        case .none:                 return "Pick a Mode"
        }
    }

    private var previewSeconds: TimeInterval {
        switch mode {
        case .some(.lockInSession): return 30
        default:                     return 10
        }
    }

    private var monitoringNote: String {
        switch mode {
        case .some(.dailyLimit):
            if dailyMonitor.isMonitoringDailyLimit {
                return "Daily limit monitoring is on. LockIn alerts when your selected apps reach \(LimitFormatter.minutes(dailyLimitMinutes)) today."
            }
            if !screenTime.authState.isApproved {
                return "Enable Screen Time access on the Apps screen to start Daily Limit monitoring."
            }
            if !familyStore.hasAnySelection {
                return "Choose real apps with Screen Time access to start Daily Limit monitoring."
            }
            return "LockIn will alert you when your selected apps reach \(LimitFormatter.minutes(dailyLimitMinutes)) today."
        case .some(.lockInSession):
            if dailyMonitor.isMonitoringLockInSession {
                return "LockIn Mode is active. LockIn alerts if you use selected apps for more than \(LimitFormatter.seconds(slipThresholdSeconds))."
            }
            if !screenTime.authState.isApproved {
                return "Enable Screen Time access on the Apps screen to start LockIn Mode."
            }
            if !familyStore.hasAnySelection {
                return "Choose real apps with Screen Time access to start LockIn Mode."
            }
            return "During this session, LockIn watches selected apps and alerts if you slip past \(LimitFormatter.seconds(slipThresholdSeconds))."
        case .none:
            return "Set up a mode to get started."
        }
    }

    /// True when the Daily Limit primary action ("Start Daily Limit") can be tapped.
    private var canStartDailyLimit: Bool {
        mode == .some(.dailyLimit)
            && screenTime.authState.isApproved
            && familyStore.hasAnySelection
            && !savedCharacterID.isEmpty
            && !SelectedClipsStorage.decode(savedClipIDsRaw).isEmpty
    }

    /// True when the LockIn Mode primary action ("Start LockIn") can be tapped.
    private var canStartLockInSession: Bool {
        mode == .some(.lockInSession)
            && screenTime.authState.isApproved
            && familyStore.hasAnySelection
            && !savedCharacterID.isEmpty
            && !SelectedClipsStorage.decode(savedClipIDsRaw).isEmpty
    }

    private var lockInSessionBlockReason: String {
        if !screenTime.authState.isApproved {
            return "Enable Screen Time access on the Apps screen first."
        }
        if !familyStore.hasAnySelection {
            return "Choose real apps with Screen Time access on the Apps screen first."
        }
        if savedCharacterID.isEmpty || SelectedClipsStorage.decode(savedClipIDsRaw).isEmpty {
            return "Pick a character and at least one saying on the Voice screen first."
        }
        return ""
    }

    var body: some View {
        ZStack {
            LockInBackground()

            ScrollView {
                VStack(alignment: .leading, spacing: LockInSpacing.xl) {
                    topBar
                    header
                    if notificationManager.authState == .denied {
                        permissionWarning
                    }
                    summaryCard
                    monitoringNoteCard
                    if mode == .some(.dailyLimit) {
                        dailyLimitSection
                    }
                    if mode == .some(.lockInSession) {
                        lockInSessionSection
                    }
                    if hasPendingLockIn {
                        activeSessionCard
                        cancelButton
                    } else {
                        previewButton
                    }
                    debugDisclosure
                    if let statusMessage {
                        LockInStatusBanner(message: statusMessage)
                    }
                }
                .padding(.horizontal, LockInSpacing.xl)
                .padding(.top, LockInSpacing.s)
                .padding(.bottom, LockInSpacing.xxxl)
            }
        }
        .navigationBarBackButtonHidden(true)
        .toolbar(.hidden, for: .navigationBar)
        .task {
            await notificationManager.refreshAuthorizationStatus()
            if notificationManager.authState == .unknown && !hasRequestedPermission {
                hasRequestedPermission = true
                _ = await notificationManager.requestNotificationPermission()
            }
            await refreshPending()
        }
        .onAppear {
            // Reflect OS-truth on every visit (monitoring persists across launches).
            dailyMonitor.refreshStatus()
            dailyMonitor.debugCurrentActivities()
            screenTime.refreshAuthorizationStatus()
            refreshDebugLog()
        }
        .onChange(of: showDebugSection) { _, opened in
            if opened { refreshDebugLog() }
        }
        .onChange(of: dailyMonitor.isMonitoringLockInSession) { _, _ in
            refreshDebugLog()
        }
        .onChange(of: dailyMonitor.isMonitoringDailyLimit) { _, _ in
            refreshDebugLog()
        }
        .onChange(of: dailyMonitor.isMonitoringDebugWake) { _, _ in
            refreshDebugLog()
        }
    }

    // MARK: - Top bar / header

    private var topBar: some View {
        HStack(spacing: 12) {
            LockInBackPill(action: { dismiss() }, label: "Home")
            Spacer()
            PillBadge(
                text: topBarPillText,
                style: topBarPillIsActive ? .accent : .neutral,
                systemImage: topBarPillIcon
            )
        }
    }

    private var topBarPillText: String {
        if dailyMonitor.isMonitoringLockInSession { return "LockIn active" }
        if dailyMonitor.isMonitoringDailyLimit    { return "Monitoring" }
        if hasPendingLockIn                       { return "Preview" }
        return mode?.displayName ?? "No mode"
    }

    private var topBarPillIcon: String {
        if dailyMonitor.isMonitoringLockInSession { return "scope" }
        if dailyMonitor.isMonitoringDailyLimit    { return "dot.radiowaves.left.and.right" }
        if hasPendingLockIn                       { return "hourglass" }
        return mode?.systemImage ?? "switch.2"
    }

    private var topBarPillIsActive: Bool {
        dailyMonitor.isMonitoringDailyLimit
            || dailyMonitor.isMonitoringLockInSession
            || hasPendingLockIn
    }

    private var header: some View {
        VStack(alignment: .leading, spacing: 8) {
            LockInType.screenTitle(headerTitle)
            LockInType.screenSubtitle(headerSubtitle)
        }
    }

    private var headerTitle: String {
        switch mode {
        case .some(.dailyLimit):    return "Daily Limit"
        case .some(.lockInSession): return "LockIn Mode"
        case .none:                 return "LockIn"
        }
    }

    private var headerSubtitle: String {
        switch mode {
        case .some(.dailyLimit):    return "Selected apps and your daily limit."
        case .some(.lockInSession): return "Focus window and your slip threshold."
        case .none:                 return "Choose a mode to get started."
        }
    }

    private var permissionWarning: some View {
        HStack(alignment: .top, spacing: 12) {
            Image(systemName: "bell.slash.fill")
                .font(.system(size: 16, weight: .bold))
                .foregroundStyle(LockInColor.warning)
                .padding(.top, 1)
            VStack(alignment: .leading, spacing: 4) {
                Text("Notifications are disabled")
                    .font(.system(size: 14, weight: .bold, design: .rounded))
                    .foregroundStyle(LockInColor.textPrimary)
                Text("LockIn alerts cannot fire until notifications are enabled in Settings.")
                    .font(.system(size: 12.5, weight: .medium, design: .rounded))
                    .foregroundStyle(LockInColor.textSecondary)
                    .fixedSize(horizontal: false, vertical: true)
            }
            Spacer(minLength: 0)
        }
        .padding(14)
        .frame(maxWidth: .infinity, alignment: .leading)
        .background(
            RoundedRectangle(cornerRadius: LockInRadius.m, style: .continuous)
                .fill(LockInColor.warning.opacity(0.10))
        )
        .overlay(
            RoundedRectangle(cornerRadius: LockInRadius.m, style: .continuous)
                .strokeBorder(LockInColor.warning.opacity(0.32), lineWidth: 1)
        )
    }

    // MARK: - Summary card

    private var summaryCard: some View {
        LockInCard {
            VStack(spacing: 0) {
                ForEach(Array(summaryRows.enumerated()), id: \.offset) { (i, row) in
                    if i > 0 {
                        Divider().overlay(LockInColor.border)
                    }
                    SetupSummaryRow(
                        label: row.label,
                        value: row.value,
                        systemImage: row.icon,
                        accent: row.accent,
                        trailingIcon: nil
                    )
                    .padding(.vertical, 10)
                }
            }
        }
    }

    /// One source of truth for the summary content per mode.
    private var summaryRows: [SummaryRow] {
        switch mode {
        case .some(.dailyLimit):
            return [
                SummaryRow(label: "Mode",     value: "Daily Limit",                                  icon: "hourglass",  accent: LockInColor.textSecondary),
                SummaryRow(label: "Apps",     value: appsValueLabel,                                 icon: "apps.iphone", accent: LockInColor.textSecondary),
                SummaryRow(label: "Limit",    value: "\(LimitFormatter.minutes(dailyLimitMinutes)) per day", icon: "timer",   accent: LockInColor.textSecondary),
                SummaryRow(label: "Character", value: selectedCharacter.name,                        icon: "waveform",    accent: selectedCharacter.accent),
                SummaryRow(label: "Sayings",  value: sayingsLabel,                                   icon: "quote.bubble", accent: LockInColor.textSecondary)
            ]
        case .some(.lockInSession):
            return [
                SummaryRow(label: "Mode",     value: "LockIn Mode",                                  icon: "scope",       accent: LockInColor.textSecondary),
                SummaryRow(label: "Session",  value: LimitFormatter.minutes(sessionLengthMinutes),    icon: "clock",       accent: LockInColor.textSecondary),
                SummaryRow(label: "Slip",     value: LimitFormatter.seconds(slipThresholdSeconds),    icon: "exclamationmark.triangle", accent: LockInColor.textSecondary),
                SummaryRow(label: "Apps",     value: appsValueLabel,                                 icon: "apps.iphone", accent: LockInColor.textSecondary),
                SummaryRow(label: "Character", value: selectedCharacter.name,                        icon: "waveform",    accent: selectedCharacter.accent),
                SummaryRow(label: "Sayings",  value: sayingsLabel,                                   icon: "quote.bubble", accent: LockInColor.textSecondary)
            ]
        case .none:
            return [
                SummaryRow(label: "Mode",     value: "Not set",     icon: "switch.2",    accent: LockInColor.textSecondary),
                SummaryRow(label: "Apps",     value: appsValueLabel, icon: "apps.iphone", accent: LockInColor.textSecondary),
                SummaryRow(label: "Character", value: selectedCharacter.name, icon: "waveform", accent: selectedCharacter.accent)
            ]
        }
    }

    // MARK: - Honest monitoring note

    private var monitoringNoteCard: some View {
        HStack(alignment: .top, spacing: 10) {
            Image(systemName: "info.circle")
                .font(.system(size: 13, weight: .semibold))
                .foregroundStyle(LockInColor.textTertiary)
                .padding(.top, 1)
            Text(monitoringNote)
                .font(.system(size: 12.5, weight: .medium, design: .rounded))
                .foregroundStyle(LockInColor.textTertiary)
                .fixedSize(horizontal: false, vertical: true)
            Spacer(minLength: 0)
        }
        .padding(12)
        .frame(maxWidth: .infinity, alignment: .leading)
    }

    // MARK: - Active session

    private var activeSessionCard: some View {
        LockInCard(emphasis: .accent) {
            VStack(alignment: .leading, spacing: 10) {
                TimelineView(.periodic(from: .now, by: 1.0)) { context in
                    let remaining = remainingSeconds(now: context.date)
                    VStack(alignment: .leading, spacing: 4) {
                        Text("FIRES IN")
                            .font(.system(size: 10, weight: .heavy, design: .rounded))
                            .tracking(1.4)
                            .foregroundStyle(LockInColor.textTertiary)
                        Text(formatCountdown(remaining))
                            .font(.system(size: 40, weight: .black, design: .monospaced))
                            .foregroundStyle(LockInColor.textPrimary)
                            .contentTransition(.numericText())
                    }
                }
                HStack(spacing: 6) {
                    Image(systemName: "waveform")
                        .font(.system(size: 11, weight: .bold))
                        .foregroundStyle(selectedCharacter.accent)
                    Text("\(selectedCharacter.name) · \(selectedClips.count) saying\(selectedClips.count == 1 ? "" : "s")")
                        .font(.system(size: 13, weight: .medium, design: .rounded))
                        .foregroundStyle(LockInColor.textSecondary)
                }
            }
        }
    }

    private var cancelButton: some View {
        PrimaryButton(
            title: "Cancel Session",
            systemImage: "xmark.circle.fill",
            style: .secondary
        ) {
            handleCancel()
        }
    }

    // MARK: - Daily Limit (real monitoring)

    private var dailyLimitSection: some View {
        LockInCard(emphasis: dailyMonitor.isMonitoringDailyLimit ? .accent : .standard) {
            VStack(alignment: .leading, spacing: 14) {
                HStack(spacing: 10) {
                    Image(systemName: dailyMonitor.isMonitoringDailyLimit
                          ? "dot.radiowaves.left.and.right"
                          : "hourglass")
                        .font(.system(size: 13, weight: .bold))
                        .foregroundStyle(dailyMonitor.isMonitoringDailyLimit
                                         ? LockInColor.accent
                                         : LockInColor.textSecondary)
                    Text(dailyMonitor.isMonitoringDailyLimit ? "Monitoring is on" : "Daily Limit")
                        .font(.system(size: 13, weight: .heavy, design: .rounded))
                        .tracking(1.0)
                        .foregroundStyle(LockInColor.textPrimary)
                    Spacer(minLength: 0)
                    Text(LimitFormatter.minutes(dailyLimitMinutes))
                        .font(.system(size: 12, weight: .bold, design: .rounded))
                        .foregroundStyle(LockInColor.textTertiary)
                }

                if dailyMonitor.isMonitoringDailyLimit {
                    PrimaryButton(
                        title: "Stop Daily Limit",
                        systemImage: "stop.circle.fill",
                        style: .secondary
                    ) {
                        handleStopDailyLimit()
                    }
                } else {
                    PrimaryButton(
                        title: "Start Daily Limit",
                        systemImage: "bolt.fill",
                        style: .primary,
                        isEnabled: canStartDailyLimit
                    ) {
                        handleStartDailyLimit()
                    }

                    if !canStartDailyLimit {
                        Text(blockReason)
                            .font(.system(size: 12, weight: .medium, design: .rounded))
                            .foregroundStyle(LockInColor.textTertiary)
                            .fixedSize(horizontal: false, vertical: true)
                    }
                }
            }
        }
    }

    private var blockReason: String {
        if !screenTime.authState.isApproved {
            return "Enable Screen Time access on the Apps screen first."
        }
        if !familyStore.hasAnySelection {
            return "Choose real apps with Screen Time access on the Apps screen first."
        }
        if savedCharacterID.isEmpty || SelectedClipsStorage.decode(savedClipIDsRaw).isEmpty {
            return "Pick a character and at least one saying on the Voice screen first."
        }
        return ""
    }

    // MARK: - LockIn Mode session (real monitoring)

    private var lockInSessionSection: some View {
        LockInCard(emphasis: dailyMonitor.isMonitoringLockInSession ? .accent : .standard) {
            VStack(alignment: .leading, spacing: 14) {
                HStack(spacing: 10) {
                    Image(systemName: dailyMonitor.isMonitoringLockInSession ? "scope" : "scope")
                        .font(.system(size: 13, weight: .bold))
                        .foregroundStyle(dailyMonitor.isMonitoringLockInSession
                                         ? LockInColor.accent
                                         : LockInColor.textSecondary)
                    Text(dailyMonitor.isMonitoringLockInSession ? "LockIn Mode is active" : "LockIn Session")
                        .font(.system(size: 13, weight: .heavy, design: .rounded))
                        .tracking(1.0)
                        .foregroundStyle(LockInColor.textPrimary)
                    Spacer(minLength: 0)
                    Text(LimitFormatter.minutes(sessionLengthMinutes))
                        .font(.system(size: 12, weight: .bold, design: .rounded))
                        .foregroundStyle(LockInColor.textTertiary)
                }

                Text(slipDescription)
                    .font(.system(size: 12.5, weight: .medium, design: .rounded))
                    .foregroundStyle(LockInColor.textSecondary)
                    .fixedSize(horizontal: false, vertical: true)

                if !dailyMonitor.lastLockInStartDebugLines.isEmpty {
                    lockInMonitoringDebugBlock
                }

                if dailyMonitor.isMonitoringLockInSession {
                    activeSessionCountdown
                    PrimaryButton(
                        title: "End LockIn",
                        systemImage: "stop.circle.fill",
                        style: .secondary
                    ) {
                        handleEndLockInSession()
                    }
                } else {
                    PrimaryButton(
                        title: "Start LockIn",
                        systemImage: "bolt.fill",
                        style: .primary,
                        isEnabled: canStartLockInSession
                    ) {
                        handleStartLockInSession()
                    }

                    if !canStartLockInSession {
                        Text(lockInSessionBlockReason)
                            .font(.system(size: 12, weight: .medium, design: .rounded))
                            .foregroundStyle(LockInColor.textTertiary)
                            .fixedSize(horizontal: false, vertical: true)
                    }
                }
            }
        }
    }

    private var slipDescription: String {
        "Watching selected apps for \(LimitFormatter.minutes(sessionLengthMinutes)). Alert fires after \(LimitFormatter.seconds(slipThresholdSeconds)) of slip time."
    }

    private var lockInMonitoringDebugBlock: some View {
        VStack(alignment: .leading, spacing: 4) {
            ForEach(Array(dailyMonitor.lastLockInStartDebugLines.enumerated()), id: \.offset) { _, line in
                Text(line)
                    .font(.system(size: 11, weight: .medium, design: .monospaced))
                    .foregroundStyle(LockInColor.textTertiary)
                    .fixedSize(horizontal: false, vertical: true)
            }
        }
        .padding(10)
        .frame(maxWidth: .infinity, alignment: .leading)
        .background(
            RoundedRectangle(cornerRadius: 8, style: .continuous)
                .fill(LockInColor.surface.opacity(0.6))
        )
    }

    private var activeSessionCountdown: some View {
        VStack(alignment: .leading, spacing: 4) {
            TimelineView(.periodic(from: .now, by: 1.0)) { context in
                let remaining = lockInRemainingSeconds(now: context.date)
                HStack(spacing: 6) {
                    Image(systemName: "timer")
                        .font(.system(size: 11, weight: .bold))
                        .foregroundStyle(LockInColor.accent)
                    Text("Ends in \(formatRemaining(remaining))")
                        .font(.system(size: 13, weight: .heavy, design: .rounded))
                        .foregroundStyle(LockInColor.textPrimary)
                        .contentTransition(.numericText())
                    if let endsAt = dailyMonitor.lockInSessionEndsAt {
                        Spacer(minLength: 0)
                        Text("at \(endsAt.formatted(date: .omitted, time: .shortened))")
                            .font(.system(size: 12, weight: .medium, design: .rounded))
                            .foregroundStyle(LockInColor.textTertiary)
                    }
                }
            }
        }
    }

    private func lockInRemainingSeconds(now: Date) -> Int {
        guard let endsAt = dailyMonitor.lockInSessionEndsAt else { return 0 }
        return max(0, Int(endsAt.timeIntervalSince(now).rounded()))
    }

    private func formatRemaining(_ totalSeconds: Int) -> String {
        let h = totalSeconds / 3600
        let m = (totalSeconds % 3600) / 60
        let s = totalSeconds % 60
        if h > 0 {
            return String(format: "%dh %02dm %02ds", h, m, s)
        }
        return String(format: "%02dm %02ds", m, s)
    }

    // MARK: - Preview (local notification test)

    private var previewButton: some View {
        PrimaryButton(
            title: previewButtonTitle,
            systemImage: mode == nil ? "switch.2" : "play.fill",
            style: mode == .some(.dailyLimit) ? .secondary : .primary,
            isEnabled: mode != nil
        ) {
            Task { await handlePrimary() }
        }
    }

    // MARK: - Debug disclosure

    private var debugDisclosure: some View {
        VStack(alignment: .leading, spacing: 10) {
            Button {
                withAnimation(.easeOut(duration: 0.18)) { showDebugSection.toggle() }
            } label: {
                HStack(spacing: 8) {
                    Image(systemName: "chevron.right")
                        .font(.system(size: 10, weight: .bold))
                        .rotationEffect(.degrees(showDebugSection ? 90 : 0))
                    Text("Developer Debug")
                        .font(.system(size: 11, weight: .heavy, design: .rounded))
                        .tracking(1.8)
                    Spacer()
                    Text("Auth: \(notificationManager.authorizationStatusDescription)")
                        .font(.system(size: 10, weight: .heavy, design: .rounded))
                        .tracking(0.8)
                }
                .foregroundStyle(LockInColor.textTertiary)
            }
            .buttonStyle(.plain)

            if showDebugSection {
                PrimaryButton(
                    title: "Send Debug Notification (5s)",
                    systemImage: "ladybug.fill",
                    style: .secondary
                ) {
                    Task { await handleSendDebug() }
                }

                diagnosticsBlock
            }
        }
    }

    // MARK: - Diagnostics (DeviceActivity)

    private var diagnosticsBlock: some View {
        VStack(alignment: .leading, spacing: 10) {
            Text("DEVICE ACTIVITY DIAGNOSTICS")
                .font(.system(size: 10, weight: .heavy, design: .rounded))
                .tracking(1.6)
                .foregroundStyle(LockInColor.textTertiary)

            registeredActivitiesRow

            HStack(spacing: 8) {
                PrimaryButton(
                    title: "Refresh Activities",
                    systemImage: "arrow.clockwise",
                    style: .secondary
                ) {
                    handleRefreshActivities()
                }
                if dailyMonitor.isMonitoringDebugWake {
                    PrimaryButton(
                        title: "Stop Wakeup",
                        systemImage: "stop.fill",
                        style: .secondary
                    ) {
                        handleStopDebugWake()
                    }
                } else {
                    PrimaryButton(
                        title: "Test Extension Wakeup",
                        systemImage: "bolt.horizontal.fill",
                        style: .secondary
                    ) {
                        handleStartDebugWake()
                    }
                }
            }

            debugLogPanel

            if let interpretation = diagnosticInterpretation {
                Text(interpretation)
                    .font(.system(size: 11, weight: .medium, design: .rounded))
                    .foregroundStyle(LockInColor.textTertiary)
                    .fixedSize(horizontal: false, vertical: true)
            }
        }
        .padding(12)
        .frame(maxWidth: .infinity, alignment: .leading)
        .background(
            RoundedRectangle(cornerRadius: LockInRadius.m, style: .continuous)
                .fill(LockInColor.surface.opacity(0.6))
        )
        .overlay(
            RoundedRectangle(cornerRadius: LockInRadius.m, style: .continuous)
                .strokeBorder(LockInColor.border, lineWidth: 1)
        )
    }

    /// Small heuristic helper rendered under the diagnostics log so the
    /// situation is obvious without reading every line.
    private var diagnosticInterpretation: String? {
        let registered = !dailyMonitor.registeredActivityNames.isEmpty
        let extensionEverWoke = debugLogLines.contains { $0.contains("[extension]") }

        if registered && !extensionEverWoke {
            return "Monitoring is registered, but the extension has not woken yet. Press \u{201C}Test Extension Wakeup\u{201D} — [extension] logs should appear within a few minutes. If they don't, the extension binary isn't being loaded by iOS."
        }
        if registered && extensionEverWoke {
            return "Extension has woken at least once. If a real slip alert still doesn't fire, check threshold (try 1 minute) and that you actually used the selected app."
        }
        if !registered {
            return "No DeviceActivity is registered. Start LockIn Mode or press Test Extension Wakeup to register one."
        }
        return nil
    }

    private var registeredActivitiesRow: some View {
        VStack(alignment: .leading, spacing: 4) {
            Text("Registered activities: \(dailyMonitor.registeredActivityNames.count)")
                .font(.system(size: 11.5, weight: .heavy, design: .monospaced))
                .foregroundStyle(LockInColor.textSecondary)
            if dailyMonitor.registeredActivityNames.isEmpty {
                Text("(none)")
                    .font(.system(size: 11, weight: .medium, design: .monospaced))
                    .foregroundStyle(LockInColor.textTertiary)
            } else {
                ForEach(Array(dailyMonitor.registeredActivityNames.enumerated()), id: \.offset) { _, name in
                    Text("• \(name)")
                        .font(.system(size: 11, weight: .medium, design: .monospaced))
                        .foregroundStyle(LockInColor.textTertiary)
                        .lineLimit(1)
                        .truncationMode(.middle)
                }
            }
        }
    }

    private var debugLogPanel: some View {
        VStack(alignment: .leading, spacing: 6) {
            HStack {
                Text("Shared debug log (last \(debugLogLines.count))")
                    .font(.system(size: 11, weight: .heavy, design: .rounded))
                    .tracking(0.8)
                    .foregroundStyle(LockInColor.textTertiary)
                Spacer()
                Button("Refresh") {
                    refreshDebugLog()
                }
                .font(.system(size: 11, weight: .bold, design: .rounded))
                .foregroundStyle(LockInColor.accent)
                Button("Clear") {
                    dailyMonitor.clearDebugLog()
                    refreshDebugLog()
                }
                .font(.system(size: 11, weight: .bold, design: .rounded))
                .foregroundStyle(LockInColor.warning)
            }

            if debugLogLines.isEmpty {
                Text("(empty)")
                    .font(.system(size: 11, weight: .medium, design: .monospaced))
                    .foregroundStyle(LockInColor.textTertiary)
            } else {
                ScrollView {
                    VStack(alignment: .leading, spacing: 2) {
                        ForEach(Array(debugLogLines.enumerated()), id: \.offset) { _, line in
                            Text(line)
                                .font(.system(size: 10.5, weight: .medium, design: .monospaced))
                                .foregroundStyle(LockInColor.textSecondary)
                                .frame(maxWidth: .infinity, alignment: .leading)
                                .fixedSize(horizontal: false, vertical: true)
                        }
                    }
                }
                .frame(maxHeight: 220)
            }
        }
        .id(debugLogRefreshTrigger)
    }

    private func handleRefreshActivities() {
        dailyMonitor.debugCurrentActivities()
        refreshDebugLog()
    }

    private func handleStartDebugWake() {
        _ = dailyMonitor.startDebugWakeMonitoring()
        refreshDebugLog()
        showStatus("Test wakeup registered. Expect intervalDidStart within ~30s.")
    }

    private func handleStopDebugWake() {
        dailyMonitor.stopDebugWakeMonitoring()
        refreshDebugLog()
        showStatus("Test wakeup stopped.")
    }

    private func refreshDebugLog() {
        debugLogLines = ScreenTimeDebugLogStore.tail(25)
        debugLogRefreshTrigger &+= 1
    }

    // MARK: - Daily Limit actions

    private func handleStartDailyLimit() {
        guard canStartDailyLimit else {
            showStatus(blockReason)
            return
        }
        let result = dailyMonitor.startDailyLimitMonitoring(
            selection: familyStore.selection,
            dailyLimitMinutes: dailyLimitMinutes,
            isAuthorized: screenTime.authState.isApproved
        )
        switch result {
        case .success:
            showStatus("Daily limit monitoring is on. LockIn will alert you when your selected apps reach \(LimitFormatter.minutes(dailyLimitMinutes)) today.")
        case .failure(let error):
            showStatus(error.errorDescription ?? "Could not start Daily Limit.")
        }
    }

    private func handleStopDailyLimit() {
        dailyMonitor.stopDailyLimitMonitoring()
        showStatus("Daily limit monitoring stopped.")
    }

    // MARK: - LockIn Mode actions

    private func handleStartLockInSession() {
        guard canStartLockInSession else {
            showStatus(lockInSessionBlockReason)
            return
        }
        let result = dailyMonitor.startLockInSessionMonitoring(
            selection: familyStore.selection,
            sessionLengthMinutes: sessionLengthMinutes,
            slipThresholdSeconds: slipThresholdSeconds,
            isAuthorized: screenTime.authState.isApproved
        )
        switch result {
        case .success:
            let endsAt = dailyMonitor.lockInSessionEndsAt
                .map { "Ends at \($0.formatted(date: .omitted, time: .shortened))." }
                ?? ""
            showStatus("LockIn Mode is active. \(endsAt) Alert fires after \(LimitFormatter.seconds(slipThresholdSeconds)) of slip time.")
        case .failure(let error):
            showStatus(error.errorDescription ?? "Could not start LockIn Mode.")
        }
    }

    private func handleEndLockInSession() {
        dailyMonitor.stopLockInSessionMonitoring()
        showStatus("LockIn Mode ended.")
    }

    // MARK: - Preview actions

    private func handlePrimary() async {
        switch notificationManager.authState {
        case .unknown:
            let granted = await notificationManager.requestNotificationPermission()
            guard granted else {
                showStatus("Enable notifications in Settings to preview alerts.")
                return
            }
        case .denied:
            showStatus("Notifications are disabled. Enable them in Settings.")
            return
        case .authorized:
            break
        }

        let candidates = selectedClips
        guard !candidates.isEmpty else {
            showStatus("Pick at least one saying on the Voice screen first.")
            return
        }

        let seconds = previewSeconds
        let scheduled = await notificationManager.scheduleLockInAlert(
            candidates: candidates,
            shuffle: shuffleSayings,
            after: seconds
        )
        if scheduled {
            scheduledFireEpoch = Date().addingTimeInterval(seconds).timeIntervalSince1970
        }
        await refreshPending()

        if scheduled {
            let label = mode == .some(.lockInSession) ? "Preview session started." : "Preview scheduled."
            showStatus("\(label) Fires in \(Int(seconds))s.")
        } else {
            showStatus("Could not start preview. Check notification permissions.")
        }
    }

    private func handleCancel() {
        notificationManager.cancelLockInAlert()
        scheduledFireEpoch = 0
        Task {
            await refreshPending()
            showStatus("Cancelled.")
        }
    }

    private func handleSendDebug() async {
        switch notificationManager.authState {
        case .unknown:
            let granted = await notificationManager.requestNotificationPermission()
            guard granted else {
                showStatus("Enable notifications in Settings to test alerts.")
                return
            }
        case .denied:
            showStatus("Notifications are disabled. Enable them in Settings.")
            return
        case .authorized:
            break
        }

        let scheduled = await notificationManager.sendImmediateDebugNotification()
        if scheduled {
            showStatus("Debug notification scheduled for 5 seconds from now.")
        } else {
            showStatus("Could not schedule debug notification.")
        }
    }

    private func refreshPending() async {
        let hasIt = await notificationManager.hasPendingLockInAlert()
        await MainActor.run { hasPendingLockIn = hasIt }
        if !hasIt {
            scheduledFireEpoch = 0
        }
    }

    private func remainingSeconds(now: Date) -> Int {
        guard let fire = scheduledFireDate else { return 0 }
        return max(0, Int(fire.timeIntervalSince(now).rounded()))
    }

    private func formatCountdown(_ seconds: Int) -> String {
        let m = seconds / 60
        let s = seconds % 60
        return String(format: "%02d:%02d", m, s)
    }

    private func showStatus(_ message: String) {
        withAnimation(.easeOut(duration: 0.2)) { statusMessage = message }
        Task {
            try? await Task.sleep(nanoseconds: 5_000_000_000)
            await MainActor.run {
                withAnimation(.easeOut(duration: 0.2)) { statusMessage = nil }
            }
        }
    }
}

// MARK: - Row model

private struct SummaryRow {
    let label: String
    let value: String
    let icon: String
    let accent: Color
}

// MARK: - Local SessionKeys

/// Lives here (instead of the deleted LockInSession.swift) so the running
/// session epoch persists between visits to this screen.
enum SessionKeys {
    static let scheduledFireDate = "lockin.session.scheduledFireDate"
}

#Preview {
    NavigationStack {
        StartLockInView()
    }
    .preferredColorScheme(.dark)
}
