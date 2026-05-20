//
//  StartLockInView.swift
//  LockIn
//
//  Created by Catherine Fratila on 5/20/26.
//

import SwiftUI
import UserNotifications

struct StartLockInView: View {
    @StateObject private var notificationManager = NotificationManager.shared
    @Environment(\.dismiss) private var dismiss

    @AppStorage(SelectedLimitKeys.minutes) private var savedLimitMinutes: Int = LockInLimitOption.defaultMinutes
    @AppStorage(SelectedAlertKeys.id) private var savedClipID: String = ""
    @AppStorage(SelectedAlertKeys.voiceName) private var savedVoiceName: String = ""
    @AppStorage(SelectedAlertKeys.notificationText) private var savedNotificationText: String = ""
    @AppStorage(SelectedAlertKeys.soundFileName) private var savedSoundFileName: String = ""

    @State private var statusMessage: String?
    @State private var hasRequestedPermission = false
    @State private var hasPendingLockIn = false

    private var selectedLimit: LockInLimitOption {
        LockInLimitOption.option(forMinutes: savedLimitMinutes)
    }

    private var selectedClip: LockInVoiceClip {
        if !savedClipID.isEmpty, let clip = LockInVoiceClip.clip(withID: savedClipID) {
            return clip
        }
        return LockInVoiceClip.defaultClip
    }

    var body: some View {
        ZStack {
            backgroundLayer.ignoresSafeArea()

            ScrollView {
                VStack(alignment: .leading, spacing: 24) {
                    topBar
                    header
                    if notificationManager.authState == .denied {
                        permissionDeniedCard
                    }
                    summaryCard
                    actionButtons
                    debugSection
                    if let statusMessage {
                        statusBanner(statusMessage)
                    }
                }
                .padding(.horizontal, 24)
                .padding(.top, 8)
                .padding(.bottom, 48)
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

    // MARK: - Background

    private var backgroundLayer: some View {
        ZStack {
            Color.black
            RadialGradient(
                colors: [
                    Color(red: 0.95, green: 0.18, blue: 0.30).opacity(0.30),
                    Color.black.opacity(0)
                ],
                center: .top,
                startRadius: 20,
                endRadius: 480
            )
            RadialGradient(
                colors: [
                    Color(red: 0.30, green: 0.10, blue: 0.45).opacity(0.22),
                    Color.black.opacity(0)
                ],
                center: .bottomLeading,
                startRadius: 20,
                endRadius: 500
            )
        }
    }

    // MARK: - Top bar

    private var topBar: some View {
        HStack(spacing: 12) {
            Button {
                dismiss()
            } label: {
                HStack(spacing: 6) {
                    Image(systemName: "chevron.left")
                        .font(.system(size: 14, weight: .bold))
                    Text("Home")
                        .font(.system(size: 15, weight: .semibold, design: .rounded))
                }
                .foregroundStyle(.white.opacity(0.85))
                .padding(.vertical, 8)
                .padding(.horizontal, 12)
                .background(Capsule().fill(Color.white.opacity(0.08)))
                .overlay(Capsule().strokeBorder(Color.white.opacity(0.10), lineWidth: 1))
            }
            .buttonStyle(.plain)

            Spacer()

            Text("START")
                .font(.system(size: 12, weight: .heavy, design: .rounded))
                .tracking(3)
                .foregroundStyle(.white.opacity(0.55))
        }
    }

    // MARK: - Header

    private var header: some View {
        VStack(alignment: .leading, spacing: 10) {
            Text("Lock In")
                .font(.system(size: 32, weight: .black, design: .rounded))
                .foregroundStyle(.white)

            Text("Start a test run. LockIn will yell at you when your limit is up.")
                .font(.system(size: 16, weight: .medium, design: .rounded))
                .foregroundStyle(.white.opacity(0.65))
                .fixedSize(horizontal: false, vertical: true)
        }
    }

    // MARK: - Permission denied warning

    private var permissionDeniedCard: some View {
        HStack(alignment: .top, spacing: 14) {
            Image(systemName: "bell.slash.fill")
                .font(.system(size: 20, weight: .bold))
                .foregroundStyle(Color.orange)
                .frame(width: 36, height: 36)
                .background(
                    RoundedRectangle(cornerRadius: 10, style: .continuous)
                        .fill(Color.orange.opacity(0.18))
                )

            VStack(alignment: .leading, spacing: 4) {
                Text("Notifications are disabled")
                    .font(.system(size: 16, weight: .bold, design: .rounded))
                    .foregroundStyle(.white)
                Text("Notifications are disabled. LockIn alerts cannot fire until notifications are enabled in Settings.")
                    .font(.system(size: 13, weight: .medium, design: .rounded))
                    .foregroundStyle(.white.opacity(0.7))
                    .fixedSize(horizontal: false, vertical: true)

                Text("Status: \(notificationManager.authorizationStatusDescription)")
                    .font(.system(size: 11, weight: .heavy, design: .rounded))
                    .tracking(1.2)
                    .foregroundStyle(.white.opacity(0.45))
                    .padding(.top, 4)
            }
        }
        .padding(16)
        .frame(maxWidth: .infinity, alignment: .leading)
        .background(
            RoundedRectangle(cornerRadius: 18, style: .continuous)
                .fill(Color.orange.opacity(0.10))
        )
        .overlay(
            RoundedRectangle(cornerRadius: 18, style: .continuous)
                .strokeBorder(Color.orange.opacity(0.35), lineWidth: 1)
        )
    }

    // MARK: - Summary card

    private var summaryCard: some View {
        VStack(alignment: .leading, spacing: 16) {
            HStack(spacing: 12) {
                summaryIcon(systemName: "timer")
                VStack(alignment: .leading, spacing: 2) {
                    Text("LIMIT")
                        .font(.system(size: 11, weight: .heavy, design: .rounded))
                        .tracking(1.8)
                        .foregroundStyle(.white.opacity(0.55))
                    Text(selectedLimit.longLabel)
                        .font(.system(size: 18, weight: .bold, design: .rounded))
                        .foregroundStyle(.white)
                }
                Spacer(minLength: 0)
            }

            Divider().background(Color.white.opacity(0.08))

            HStack(alignment: .top, spacing: 12) {
                summaryIcon(systemName: "megaphone.fill")
                VStack(alignment: .leading, spacing: 4) {
                    Text("ALERT")
                        .font(.system(size: 11, weight: .heavy, design: .rounded))
                        .tracking(1.8)
                        .foregroundStyle(.white.opacity(0.55))
                    Text(selectedClip.voiceName)
                        .font(.system(size: 18, weight: .bold, design: .rounded))
                        .foregroundStyle(.white)
                    Text("\u{201C}\(selectedClip.notificationText)\u{201D}")
                        .font(.system(size: 14, weight: .semibold, design: .rounded))
                        .foregroundStyle(.white.opacity(0.85))
                        .fixedSize(horizontal: false, vertical: true)
                }
                Spacer(minLength: 0)
            }

            if hasPendingLockIn {
                pendingBadge
            }
        }
        .padding(18)
        .frame(maxWidth: .infinity, alignment: .leading)
        .background(
            RoundedRectangle(cornerRadius: 22, style: .continuous)
                .fill(Color.white.opacity(0.06))
        )
        .overlay(
            RoundedRectangle(cornerRadius: 22, style: .continuous)
                .strokeBorder(Color.white.opacity(0.10), lineWidth: 1)
        )
    }

    private func summaryIcon(systemName: String) -> some View {
        ZStack {
            RoundedRectangle(cornerRadius: 12, style: .continuous)
                .fill(
                    LinearGradient(
                        colors: [Color.red, Color.orange],
                        startPoint: .topLeading,
                        endPoint: .bottomTrailing
                    )
                )
                .frame(width: 42, height: 42)
            Image(systemName: systemName)
                .font(.system(size: 18, weight: .bold))
                .foregroundStyle(.white)
        }
    }

    private var pendingBadge: some View {
        HStack(spacing: 10) {
            Image(systemName: "hourglass")
                .font(.system(size: 13, weight: .bold))
            Text("LockIn alert is scheduled and pending.")
                .font(.system(size: 13, weight: .semibold, design: .rounded))
            Spacer(minLength: 0)
        }
        .foregroundStyle(.white.opacity(0.85))
        .padding(.vertical, 10)
        .padding(.horizontal, 12)
        .background(
            RoundedRectangle(cornerRadius: 12, style: .continuous)
                .fill(Color.orange.opacity(0.18))
        )
        .overlay(
            RoundedRectangle(cornerRadius: 12, style: .continuous)
                .strokeBorder(Color.orange.opacity(0.35), lineWidth: 1)
        )
    }

    // MARK: - Action buttons

    private var actionButtons: some View {
        VStack(spacing: 12) {
            Button {
                Task { await handleStartTestLockIn() }
            } label: {
                HStack(spacing: 10) {
                    Image(systemName: "bolt.fill")
                        .font(.system(size: 16, weight: .bold))
                    Text("Start Test LockIn")
                        .font(.system(size: 17, weight: .bold, design: .rounded))
                }
                .foregroundStyle(.white)
                .frame(maxWidth: .infinity)
                .padding(.vertical, 16)
                .background(
                    LinearGradient(
                        colors: [
                            Color(red: 0.95, green: 0.18, blue: 0.30),
                            Color(red: 0.65, green: 0.08, blue: 0.20)
                        ],
                        startPoint: .topLeading,
                        endPoint: .bottomTrailing
                    )
                )
                .clipShape(RoundedRectangle(cornerRadius: 16, style: .continuous))
                .overlay(
                    RoundedRectangle(cornerRadius: 16, style: .continuous)
                        .strokeBorder(Color.white.opacity(0.18), lineWidth: 1)
                )
            }
            .buttonStyle(PressableScaleStyle())

            Button {
                handleCancelLockIn()
            } label: {
                HStack(spacing: 10) {
                    Image(systemName: "xmark.circle.fill")
                        .font(.system(size: 15, weight: .bold))
                    Text("Cancel LockIn")
                        .font(.system(size: 16, weight: .semibold, design: .rounded))
                }
                .foregroundStyle(.white.opacity(hasPendingLockIn ? 0.95 : 0.5))
                .frame(maxWidth: .infinity)
                .padding(.vertical, 14)
                .background(
                    RoundedRectangle(cornerRadius: 16, style: .continuous)
                        .fill(Color.white.opacity(0.06))
                )
                .overlay(
                    RoundedRectangle(cornerRadius: 16, style: .continuous)
                        .strokeBorder(Color.white.opacity(0.12), lineWidth: 1)
                )
            }
            .buttonStyle(PressableScaleStyle())
            .disabled(!hasPendingLockIn)
        }
    }

    // MARK: - Debug section

    private var debugSection: some View {
        VStack(alignment: .leading, spacing: 10) {
            Text("DEBUG")
                .font(.system(size: 11, weight: .heavy, design: .rounded))
                .tracking(2)
                .foregroundStyle(.white.opacity(0.45))

            Button {
                Task { await handleSendDebugNotification() }
            } label: {
                HStack(spacing: 10) {
                    Image(systemName: "ladybug.fill")
                        .font(.system(size: 14, weight: .bold))
                    Text("Send Debug Notification")
                        .font(.system(size: 15, weight: .semibold, design: .rounded))
                    Spacer(minLength: 0)
                    Text("5s")
                        .font(.system(size: 12, weight: .heavy, design: .rounded))
                        .tracking(1)
                        .foregroundStyle(.white.opacity(0.55))
                }
                .foregroundStyle(.white)
                .padding(.vertical, 14)
                .padding(.horizontal, 16)
                .frame(maxWidth: .infinity)
                .background(
                    RoundedRectangle(cornerRadius: 14, style: .continuous)
                        .fill(Color.white.opacity(0.05))
                )
                .overlay(
                    RoundedRectangle(cornerRadius: 14, style: .continuous)
                        .strokeBorder(Color.white.opacity(0.10), lineWidth: 1)
                )
            }
            .buttonStyle(PressableScaleStyle())

            Text("Auth status: \(notificationManager.authorizationStatusDescription)")
                .font(.system(size: 11, weight: .medium, design: .rounded))
                .foregroundStyle(.white.opacity(0.4))
        }
    }

    // MARK: - Status banner

    private func statusBanner(_ message: String) -> some View {
        HStack(alignment: .top, spacing: 12) {
            Image(systemName: "sparkles")
                .font(.system(size: 14, weight: .bold))
                .foregroundStyle(Color.orange)
            Text(message)
                .font(.system(size: 14, weight: .medium, design: .rounded))
                .foregroundStyle(.white.opacity(0.85))
                .fixedSize(horizontal: false, vertical: true)
            Spacer(minLength: 0)
        }
        .padding(14)
        .frame(maxWidth: .infinity, alignment: .leading)
        .background(
            RoundedRectangle(cornerRadius: 14, style: .continuous)
                .fill(Color.white.opacity(0.06))
        )
        .overlay(
            RoundedRectangle(cornerRadius: 14, style: .continuous)
                .strokeBorder(Color.orange.opacity(0.30), lineWidth: 1)
        )
        .transition(.opacity)
    }

    // MARK: - Actions

    private func handleStartTestLockIn() async {
        switch notificationManager.authState {
        case .unknown:
            let granted = await notificationManager.requestNotificationPermission()
            guard granted else {
                showStatus("Enable notifications in Settings to start a test LockIn.")
                return
            }
        case .denied:
            showStatus("Notifications are disabled. Enable them in Settings.")
            return
        case .authorized:
            break
        }

        let clip = selectedClip
        let limit = selectedLimit
        let seconds = TimeInterval(limit.minutes * 60)
        let scheduled = await notificationManager.scheduleLockInAlert(clip: clip, after: seconds)
        await refreshPending()

        if scheduled {
            showStatus(
                "Locked in. \(limit.longLabel) on the clock. \(clip.voiceName) will fire: \u{201C}\(clip.notificationText)\u{201D}"
            )
        } else {
            showStatus("Could not schedule LockIn alert. Check notification permissions.")
        }
    }

    private func handleCancelLockIn() {
        notificationManager.cancelLockInAlert()
        Task {
            await refreshPending()
            showStatus("Cancelled. No LockIn alert scheduled.")
        }
    }

    private func handleSendDebugNotification() async {
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
        await refreshPending()
        if scheduled {
            showStatus("Debug notification scheduled for 5 seconds from now.")
        } else {
            showStatus("Could not schedule debug notification. Check auth status.")
        }
    }

    private func refreshPending() async {
        let pending = await UNUserNotificationCenter.current().pendingNotificationRequests()
        let hasIt = pending.contains { $0.identifier == NotificationManager.lockInRequestIdentifier }
        await MainActor.run { hasPendingLockIn = hasIt }
    }

    private func showStatus(_ message: String) {
        withAnimation(.easeOut(duration: 0.2)) {
            statusMessage = message
        }
        Task {
            try? await Task.sleep(nanoseconds: 6_000_000_000)
            await MainActor.run {
                withAnimation(.easeOut(duration: 0.2)) {
                    statusMessage = nil
                }
            }
        }
    }
}

#Preview {
    NavigationStack {
        StartLockInView()
    }
    .preferredColorScheme(.dark)
}
