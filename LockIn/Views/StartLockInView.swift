//
//  StartLockInView.swift
//  LockIn
//

import SwiftUI
import UserNotifications

struct StartLockInView: View {
    @StateObject private var notificationManager = NotificationManager.shared
    @Environment(\.dismiss) private var dismiss

    @AppStorage(SelectedLimitKeys.minutes) private var savedLimitMinutes: Int = LockInLimitOption.defaultMinutes
    @AppStorage(SelectedAppsKeys.ids) private var savedAppIDsRaw: String = ""
    @AppStorage(SelectedVoiceKeys.characterId) private var savedCharacterID: String = ""
    @AppStorage(SelectedVoiceKeys.clipId) private var savedClipID: String = ""
    @AppStorage(SessionKeys.scheduledFireDate) private var scheduledFireEpoch: Double = 0

    @State private var statusMessage: String?
    @State private var hasRequestedPermission = false
    @State private var hasPendingLockIn = false
    @State private var selectedDurationOption: DurationOption
    @State private var showDebugSection = false

    enum DurationOption: Hashable {
        case seconds(Int)
        case savedLimit

        func seconds(savedLimitMinutes: Int) -> TimeInterval {
            switch self {
            case .seconds(let s): return TimeInterval(s)
            case .savedLimit:     return TimeInterval(savedLimitMinutes * 60)
            }
        }

        func label(savedLimitMinutes: Int) -> String {
            switch self {
            case .seconds(let s) where s < 60: return "\(s) sec"
            case .seconds(let s):              return "\(s / 60) min"
            case .savedLimit:
                let limit = LockInLimitOption.option(forMinutes: savedLimitMinutes)
                return "Limit \u{00B7} \(limit.shortLabel)"
            }
        }
    }

    init() {
        _selectedDurationOption = State(initialValue: .seconds(30))
    }

    // MARK: - Derived state

    private var selectedCharacter: VoiceCharacter {
        VoiceLibrary.character(withID: savedCharacterID) ?? VoiceLibrary.defaultCharacter
    }

    private var selectedClip: VoiceClip {
        VoiceLibrary.resolveClip(characterID: savedCharacterID, clipID: savedClipID)
    }

    private var selectedAppCount: Int {
        SelectedAppsStorage.decode(savedAppIDsRaw).count
    }

    private var appsValueLabel: String {
        switch selectedAppCount {
        case 0: return "No apps selected"
        case 1: return "1 app selected"
        default: return "\(selectedAppCount) apps selected"
        }
    }

    private var savedLimit: LockInLimitOption {
        LockInLimitOption.option(forMinutes: savedLimitMinutes)
    }

    private var scheduledFireDate: Date? {
        scheduledFireEpoch > 0 ? Date(timeIntervalSince1970: scheduledFireEpoch) : nil
    }

    private var durationOptions: [DurationOption] {
        [.seconds(10), .seconds(30), .seconds(60), .savedLimit]
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
                    summarySection
                    if hasPendingLockIn {
                        activeSessionCard
                        cancelButton
                    } else {
                        durationSection
                        startButton
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
            PillBadge(text: hasPendingLockIn ? "Running" : "Idle", style: hasPendingLockIn ? .accent : .neutral, systemImage: hasPendingLockIn ? "hourglass" : "moon.fill")
        }
    }

    private var header: some View {
        VStack(alignment: .leading, spacing: 8) {
            LockInType.screenTitle("Start LockIn")
            LockInType.screenSubtitle("Test a session. The selected voice fires when time runs out.")
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

    // MARK: - Summary

    private var summarySection: some View {
        VStack(alignment: .leading, spacing: LockInSpacing.m) {
            SectionHeader(title: "Session Plan")
            LockInCard {
                VStack(spacing: 0) {
                    SetupSummaryRow(
                        label: "Voice",
                        value: "\(selectedCharacter.name) \u{00B7} \(selectedClip.sayingTitle)",
                        systemImage: "waveform",
                        accent: selectedCharacter.accent,
                        trailingIcon: nil
                    )
                    .padding(.vertical, 10)

                    Divider().overlay(LockInColor.border)

                    SetupSummaryRow(
                        label: "Saying",
                        value: "\u{201C}\(selectedClip.notificationText)\u{201D}",
                        systemImage: "quote.bubble",
                        accent: LockInColor.textSecondary,
                        trailingIcon: nil
                    )
                    .padding(.vertical, 10)

                    Divider().overlay(LockInColor.border)

                    HStack(spacing: 14) {
                        ZStack {
                            RoundedRectangle(cornerRadius: 10, style: .continuous)
                                .fill(LockInColor.textSecondary.opacity(0.16))
                                .frame(width: 36, height: 36)
                            Image(systemName: "speaker.wave.2.fill")
                                .font(.system(size: 14, weight: .semibold))
                                .foregroundStyle(LockInColor.textSecondary)
                        }
                        VStack(alignment: .leading, spacing: 2) {
                            Text("SOUND")
                                .font(.system(size: 10, weight: .heavy, design: .rounded))
                                .tracking(1.4)
                                .foregroundStyle(LockInColor.textTertiary)
                            Text(selectedClip.soundFileName)
                                .font(.system(size: 12, weight: .medium, design: .monospaced))
                                .foregroundStyle(LockInColor.textSecondary)
                                .lineLimit(1)
                                .truncationMode(.middle)
                        }
                        Spacer(minLength: 0)
                    }
                    .padding(.vertical, 10)

                    Divider().overlay(LockInColor.border)

                    SetupSummaryRow(
                        label: "Limit",
                        value: savedLimit.longLabel,
                        systemImage: "timer",
                        accent: LockInColor.textSecondary,
                        trailingIcon: nil
                    )
                    .padding(.vertical, 10)

                    Divider().overlay(LockInColor.border)

                    SetupSummaryRow(
                        label: "Apps",
                        value: appsValueLabel,
                        systemImage: "apps.iphone",
                        accent: LockInColor.textSecondary,
                        trailingIcon: nil
                    )
                    .padding(.vertical, 10)
                }
            }
        }
    }

    // MARK: - Active session

    private var activeSessionCard: some View {
        VStack(alignment: .leading, spacing: LockInSpacing.m) {
            SectionHeader(title: "Session Running")
            LockInCard(emphasis: .accent) {
                VStack(alignment: .leading, spacing: 12) {
                    TimelineView(.periodic(from: .now, by: 1.0)) { context in
                        let remaining = remainingSeconds(now: context.date)
                        VStack(alignment: .leading, spacing: 6) {
                            Text("FIRES IN")
                                .font(.system(size: 10, weight: .heavy, design: .rounded))
                                .tracking(1.4)
                                .foregroundStyle(LockInColor.textTertiary)
                            Text(formatCountdown(remaining))
                                .font(.system(size: 44, weight: .black, design: .monospaced))
                                .foregroundStyle(LockInColor.textPrimary)
                                .contentTransition(.numericText())
                        }
                    }

                    HStack(spacing: 6) {
                        Image(systemName: "waveform")
                            .font(.system(size: 11, weight: .bold))
                            .foregroundStyle(selectedCharacter.accent)
                        Text("\(selectedCharacter.name) will fire: \u{201C}\(selectedClip.notificationText)\u{201D}")
                            .font(.system(size: 13, weight: .medium, design: .rounded))
                            .foregroundStyle(LockInColor.textSecondary)
                            .fixedSize(horizontal: false, vertical: true)
                    }
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

    // MARK: - Duration / Start

    private var durationSection: some View {
        VStack(alignment: .leading, spacing: LockInSpacing.m) {
            SectionHeader(title: "Test Duration")
            LazyVGrid(
                columns: [
                    GridItem(.flexible(), spacing: 10),
                    GridItem(.flexible(), spacing: 10)
                ],
                spacing: 10
            ) {
                ForEach(durationOptions, id: \.self) { option in
                    Button {
                        selectedDurationOption = option
                    } label: {
                        DurationCell(
                            label: option.label(savedLimitMinutes: savedLimitMinutes),
                            isSelected: option == selectedDurationOption
                        )
                    }
                    .buttonStyle(PressableScaleStyle())
                }
            }
        }
    }

    private var startButton: some View {
        PrimaryButton(
            title: "Start Session",
            systemImage: "bolt.fill",
            style: .primary
        ) {
            Task { await handleStart() }
        }
    }

    // MARK: - Debug

    private var debugDisclosure: some View {
        VStack(alignment: .leading, spacing: 10) {
            Button {
                withAnimation(.easeOut(duration: 0.18)) {
                    showDebugSection.toggle()
                }
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

    private func handleStart() async {
        switch notificationManager.authState {
        case .unknown:
            let granted = await notificationManager.requestNotificationPermission()
            guard granted else {
                showStatus("Enable notifications in Settings to start a session.")
                return
            }
        case .denied:
            showStatus("Notifications are disabled. Enable them in Settings.")
            return
        case .authorized:
            break
        }

        let clip = selectedClip
        let seconds = selectedDurationOption.seconds(savedLimitMinutes: savedLimitMinutes)
        let scheduled = await notificationManager.scheduleLockInAlert(clip: clip, after: seconds)
        if scheduled {
            scheduledFireEpoch = Date().addingTimeInterval(seconds).timeIntervalSince1970
        }
        await refreshPending()

        if scheduled {
            showStatus("Session started. \(selectedDurationOption.label(savedLimitMinutes: savedLimitMinutes)).")
        } else {
            showStatus("Could not start session. Check notification permissions.")
        }
    }

    private func handleCancel() {
        notificationManager.cancelLockInAlert()
        scheduledFireEpoch = 0
        Task {
            await refreshPending()
            showStatus("Session cancelled.")
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

// MARK: - Duration cell

private struct DurationCell: View {
    let label: String
    let isSelected: Bool

    var body: some View {
        Text(label)
            .font(.system(size: 15, weight: .bold, design: .rounded))
            .foregroundStyle(isSelected ? .white : LockInColor.textPrimary)
            .frame(maxWidth: .infinity)
            .padding(.vertical, 14)
            .background(
                RoundedRectangle(cornerRadius: LockInRadius.m, style: .continuous)
                    .fill(isSelected ? LockInColor.accent : LockInColor.surface)
            )
            .overlay(
                RoundedRectangle(cornerRadius: LockInRadius.m, style: .continuous)
                    .strokeBorder(
                        isSelected ? LockInColor.accent.opacity(0.75) : LockInColor.border,
                        lineWidth: 1
                    )
            )
    }
}

#Preview {
    NavigationStack {
        StartLockInView()
    }
    .preferredColorScheme(.dark)
}
