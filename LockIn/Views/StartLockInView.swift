//
//  StartLockInView.swift
//  LockIn
//
//  Mode-aware preview screen. Real app monitoring will plug in later via
//  FutureScreenTimeManager once the FamilyControls entitlement lands.
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
    @AppStorage(LockInSetupKeys.appGroupID)           private var appGroupID: String        = ""
    @AppStorage(LockInSetupKeys.randomizeSayings)     private var shuffleSayings: Bool      = LockInDefaults.randomizeSayings
    @AppStorage(SelectedAppsKeys.ids)                 private var savedAppIDsRaw: String    = ""
    @AppStorage(SelectedVoiceKeys.characterId)        private var savedCharacterID: String  = ""
    @AppStorage(SelectedVoiceKeys.clipIds)            private var savedClipIDsRaw: String   = ""
    @AppStorage(SessionKeys.scheduledFireDate)        private var scheduledFireEpoch: Double = 0

    @State private var statusMessage: String?
    @State private var hasRequestedPermission = false
    @State private var hasPendingLockIn = false
    @State private var showDebugSection = false

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
        if let group = LockInAppGroup.group(withID: appGroupID),
           Set(group.appIDs) == Set(SelectedAppsStorage.decode(savedAppIDsRaw)) {
            return "\(group.name) · \(selectedAppCount)"
        }
        switch selectedAppCount {
        case 0: return "No apps selected"
        case 1: return "1 app"
        default: return "\(selectedAppCount) apps"
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

    private var primaryButtonTitle: String {
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
            return "Automatic app monitoring will turn on after Apple Screen Time permissions are enabled."
        case .some(.lockInSession):
            return "For now, this previews the alert. App monitoring connects later."
        case .none:
            return "Set up a mode to get started."
        }
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
                    if hasPendingLockIn {
                        activeSessionCard
                        cancelButton
                    } else {
                        primaryButton
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
    }

    // MARK: - Top bar / header

    private var topBar: some View {
        HStack(spacing: 12) {
            LockInBackPill(action: { dismiss() }, label: "Home")
            Spacer()
            PillBadge(
                text: hasPendingLockIn ? "Running" : (mode?.displayName ?? "No mode"),
                style: hasPendingLockIn ? .accent : .neutral,
                systemImage: hasPendingLockIn ? "hourglass" : (mode?.systemImage ?? "switch.2")
            )
        }
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

    // MARK: - Primary

    private var primaryButton: some View {
        PrimaryButton(
            title: primaryButtonTitle,
            systemImage: mode == nil ? "switch.2" : "bolt.fill",
            style: .primary,
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
            }
        }
    }

    // MARK: - Actions

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
