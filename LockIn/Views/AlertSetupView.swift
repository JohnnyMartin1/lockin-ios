//
//  AlertSetupView.swift
//  LockIn
//
//  Created by Catherine Fratila on 5/20/26.
//

import SwiftUI

struct AlertSetupView: View {
    @StateObject private var notificationManager = NotificationManager.shared
    @Environment(\.dismiss) private var dismiss

    @AppStorage(SelectedAlertKeys.id) private var savedClipID: String = ""
    @AppStorage(SelectedAlertKeys.voiceName) private var savedVoiceName: String = ""
    @AppStorage(SelectedAlertKeys.sayingTitle) private var savedSayingTitle: String = ""
    @AppStorage(SelectedAlertKeys.soundFileName) private var savedSoundFileName: String = ""
    @AppStorage(SelectedAlertKeys.notificationText) private var savedNotificationText: String = ""

    @State private var selectedClipID: String
    @State private var statusMessage: String?
    @State private var hasRequestedPermission = false

    private let clips = LockInVoiceClip.bundled

    init() {
        let stored = UserDefaults.standard.string(forKey: SelectedAlertKeys.id) ?? ""
        let resolved = LockInVoiceClip.clip(withID: stored)?.id ?? LockInVoiceClip.defaultClip.id
        _selectedClipID = State(initialValue: resolved)
    }

    private var selectedClip: LockInVoiceClip {
        LockInVoiceClip.clip(withID: selectedClipID) ?? LockInVoiceClip.defaultClip
    }

    private var hasUnsavedChanges: Bool {
        savedClipID != selectedClipID
    }

    var body: some View {
        ZStack {
            backgroundLayer.ignoresSafeArea()

            ScrollView {
                VStack(alignment: .leading, spacing: 28) {
                    topBar
                    header
                    if notificationManager.authState == .denied {
                        permissionDeniedCard
                    }
                    clipList
                    selectedPreview
                    actionButtons
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
                center: .bottomTrailing,
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
                .background(
                    Capsule().fill(Color.white.opacity(0.08))
                )
                .overlay(
                    Capsule().strokeBorder(Color.white.opacity(0.10), lineWidth: 1)
                )
            }
            .buttonStyle(.plain)

            Spacer()

            Text("ALERT")
                .font(.system(size: 12, weight: .heavy, design: .rounded))
                .tracking(3)
                .foregroundStyle(.white.opacity(0.55))
        }
    }

    // MARK: - Header

    private var header: some View {
        VStack(alignment: .leading, spacing: 10) {
            Text("Choose Your LockIn Alert")
                .font(.system(size: 32, weight: .black, design: .rounded))
                .foregroundStyle(.white)
                .fixedSize(horizontal: false, vertical: true)

            Text("Pick the voice that yells at you when you start wasting time.")
                .font(.system(size: 16, weight: .medium, design: .rounded))
                .foregroundStyle(.white.opacity(0.65))
                .fixedSize(horizontal: false, vertical: true)
        }
    }

    // MARK: - Permission denied banner

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
                Text("Notifications are off")
                    .font(.system(size: 16, weight: .bold, design: .rounded))
                    .foregroundStyle(.white)
                Text("LockIn alerts need notification access. Enable them in Settings to get yelled at on time.")
                    .font(.system(size: 13, weight: .medium, design: .rounded))
                    .foregroundStyle(.white.opacity(0.7))
                    .fixedSize(horizontal: false, vertical: true)
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

    // MARK: - Clip list

    private var clipList: some View {
        VStack(spacing: 12) {
            ForEach(clips) { clip in
                Button {
                    selectedClipID = clip.id
                } label: {
                    VoiceClipCard(
                        clip: clip,
                        isSelected: clip.id == selectedClipID
                    )
                }
                .buttonStyle(PressableScaleStyle())
            }
        }
    }

    // MARK: - Selected preview

    private var selectedPreview: some View {
        VStack(alignment: .leading, spacing: 12) {
            Text("PREVIEW")
                .font(.system(size: 12, weight: .heavy, design: .rounded))
                .tracking(2.5)
                .foregroundStyle(.white.opacity(0.55))

            VStack(alignment: .leading, spacing: 14) {
                HStack(spacing: 12) {
                    ZStack {
                        RoundedRectangle(cornerRadius: 12, style: .continuous)
                            .fill(
                                LinearGradient(
                                    colors: [Color.red, Color.orange],
                                    startPoint: .topLeading,
                                    endPoint: .bottomTrailing
                                )
                            )
                            .frame(width: 46, height: 46)
                        Image(systemName: "megaphone.fill")
                            .font(.system(size: 20, weight: .bold))
                            .foregroundStyle(.white)
                    }

                    VStack(alignment: .leading, spacing: 2) {
                        Text(selectedClip.voiceName)
                            .font(.system(size: 18, weight: .bold, design: .rounded))
                            .foregroundStyle(.white)
                        Text(selectedClip.sayingTitle.uppercased())
                            .font(.system(size: 11, weight: .heavy, design: .rounded))
                            .tracking(1.8)
                            .foregroundStyle(.white.opacity(0.55))
                    }
                    Spacer(minLength: 0)
                }

                VStack(alignment: .leading, spacing: 6) {
                    Text("Notification")
                        .font(.system(size: 11, weight: .heavy, design: .rounded))
                        .tracking(1.5)
                        .foregroundStyle(.white.opacity(0.45))
                    Text("\u{201C}\(selectedClip.notificationText)\u{201D}")
                        .font(.system(size: 17, weight: .semibold, design: .rounded))
                        .foregroundStyle(.white)
                        .fixedSize(horizontal: false, vertical: true)
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
    }

    // MARK: - Action buttons

    private var actionButtons: some View {
        VStack(spacing: 12) {
            Button {
                Task { await handleSendTest() }
            } label: {
                HStack(spacing: 10) {
                    Image(systemName: "bolt.fill")
                        .font(.system(size: 16, weight: .bold))
                    Text("Send Test Alert")
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
                saveSelection()
            } label: {
                HStack(spacing: 10) {
                    Image(systemName: hasUnsavedChanges ? "tray.and.arrow.down.fill" : "checkmark")
                        .font(.system(size: 15, weight: .bold))
                    Text(hasUnsavedChanges ? "Save Alert" : "Saved")
                        .font(.system(size: 16, weight: .semibold, design: .rounded))
                }
                .foregroundStyle(.white.opacity(hasUnsavedChanges ? 0.95 : 0.6))
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
            .disabled(!hasUnsavedChanges)
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

    private func saveSelection() {
        let clip = selectedClip
        savedClipID = clip.id
        savedVoiceName = clip.voiceName
        savedSayingTitle = clip.sayingTitle
        savedSoundFileName = clip.soundFileName
        savedNotificationText = clip.notificationText
        showStatus("Saved. \(clip.voiceName) is locked in.")
    }

    private func handleSendTest() async {
        switch notificationManager.authState {
        case .unknown:
            let granted = await notificationManager.requestNotificationPermission()
            guard granted else {
                showStatus("Enable notifications in Settings to test alerts.")
                return
            }
        case .denied:
            showStatus("Notifications are off. Enable them in Settings.")
            return
        case .authorized:
            break
        }

        notificationManager.sendTestNotification(clip: selectedClip)
        showStatus("Test alert in 3 seconds. Lock or background your phone to hear it.")
    }

    private func showStatus(_ message: String) {
        withAnimation(.easeOut(duration: 0.2)) {
            statusMessage = message
        }
        Task {
            try? await Task.sleep(nanoseconds: 5_000_000_000)
            await MainActor.run {
                withAnimation(.easeOut(duration: 0.2)) {
                    statusMessage = nil
                }
            }
        }
    }
}

// MARK: - Voice clip card

private struct VoiceClipCard: View {
    let clip: LockInVoiceClip
    let isSelected: Bool

    var body: some View {
        HStack(alignment: .top, spacing: 14) {
            ZStack {
                RoundedRectangle(cornerRadius: 12, style: .continuous)
                    .fill(iconBackground)
                    .frame(width: 46, height: 46)
                Image(systemName: "waveform")
                    .font(.system(size: 20, weight: .bold))
                    .foregroundStyle(iconForeground)
            }

            VStack(alignment: .leading, spacing: 6) {
                HStack(spacing: 8) {
                    Text(clip.voiceName)
                        .font(.system(size: 17, weight: .bold, design: .rounded))
                        .foregroundStyle(.white)
                    if clip.isPremium {
                        premiumBadge
                    }
                    Spacer(minLength: 0)
                    if isSelected {
                        Image(systemName: "checkmark.circle.fill")
                            .font(.system(size: 20, weight: .bold))
                            .foregroundStyle(
                                LinearGradient(
                                    colors: [Color.red, Color.orange],
                                    startPoint: .topLeading,
                                    endPoint: .bottomTrailing
                                )
                            )
                    }
                }

                Text(clip.sayingTitle.uppercased())
                    .font(.system(size: 11, weight: .heavy, design: .rounded))
                    .tracking(1.8)
                    .foregroundStyle(.white.opacity(0.55))

                Text("\u{201C}\(clip.notificationText)\u{201D}")
                    .font(.system(size: 14, weight: .semibold, design: .rounded))
                    .foregroundStyle(.white.opacity(0.92))
                    .fixedSize(horizontal: false, vertical: true)

                Text(clip.subtitle)
                    .font(.system(size: 12, weight: .medium, design: .rounded))
                    .foregroundStyle(.white.opacity(0.55))
                    .fixedSize(horizontal: false, vertical: true)
            }
        }
        .padding(16)
        .frame(maxWidth: .infinity, alignment: .leading)
        .background(
            RoundedRectangle(cornerRadius: 20, style: .continuous)
                .fill(cardFill)
        )
        .overlay(
            RoundedRectangle(cornerRadius: 20, style: .continuous)
                .strokeBorder(borderColor, lineWidth: isSelected ? 1.5 : 1)
        )
        .shadow(
            color: isSelected
                ? Color(red: 0.95, green: 0.18, blue: 0.30).opacity(0.35)
                : Color.clear,
            radius: 16,
            x: 0,
            y: 6
        )
    }

    private var premiumBadge: some View {
        HStack(spacing: 4) {
            Image(systemName: "crown.fill")
                .font(.system(size: 9, weight: .heavy))
            Text("PREMIUM SOON")
                .font(.system(size: 9, weight: .heavy, design: .rounded))
                .tracking(0.8)
        }
        .foregroundStyle(.black)
        .padding(.horizontal, 7)
        .padding(.vertical, 4)
        .background(
            Capsule().fill(
                LinearGradient(
                    colors: [Color.yellow, Color.orange],
                    startPoint: .topLeading,
                    endPoint: .bottomTrailing
                )
            )
        )
    }

    private var cardFill: Color {
        isSelected ? Color.white.opacity(0.10) : Color.white.opacity(0.05)
    }

    private var borderColor: Color {
        isSelected
            ? Color(red: 0.95, green: 0.18, blue: 0.30).opacity(0.85)
            : Color.white.opacity(0.08)
    }

    private var iconBackground: Color {
        isSelected
            ? Color(red: 0.95, green: 0.18, blue: 0.30).opacity(0.30)
            : Color.white.opacity(0.10)
    }

    private var iconForeground: Color {
        isSelected
            ? Color(red: 1.0, green: 0.55, blue: 0.40)
            : .white
    }
}

// MARK: - Press style

struct PressableScaleStyle: ButtonStyle {
    func makeBody(configuration: Configuration) -> some View {
        configuration.label
            .scaleEffect(configuration.isPressed ? 0.97 : 1.0)
            .opacity(configuration.isPressed ? 0.9 : 1.0)
            .animation(.easeOut(duration: 0.12), value: configuration.isPressed)
    }
}

#Preview {
    NavigationStack {
        AlertSetupView()
    }
    .preferredColorScheme(.dark)
}
