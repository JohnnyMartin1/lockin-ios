//
//  AlertSetupView.swift
//  LockIn
//

import SwiftUI

struct AlertSetupView: View {
    @StateObject private var notificationManager = NotificationManager.shared
    @Environment(\.dismiss) private var dismiss

    @AppStorage(SelectedVoiceKeys.characterId) private var savedCharacterID: String = ""
    @AppStorage(SelectedVoiceKeys.clipId) private var savedClipID: String = ""

    @State private var selectedCharacterID: String
    @State private var selectedClipID: String
    @State private var statusMessage: String?
    @State private var hasRequestedPermission = false

    private let characters = VoiceLibrary.characters

    init() {
        let storedCharacter = UserDefaults.standard.string(forKey: SelectedVoiceKeys.characterId) ?? ""
        let storedClip = UserDefaults.standard.string(forKey: SelectedVoiceKeys.clipId) ?? ""
        let resolvedClip = VoiceLibrary.resolveClip(characterID: storedCharacter, clipID: storedClip)
        _selectedCharacterID = State(initialValue: resolvedClip.characterId)
        _selectedClipID = State(initialValue: resolvedClip.id)
    }

    private var selectedCharacter: VoiceCharacter {
        VoiceLibrary.character(withID: selectedCharacterID) ?? VoiceLibrary.defaultCharacter
    }

    private var selectedClip: VoiceClip {
        VoiceLibrary.resolveClip(characterID: selectedCharacterID, clipID: selectedClipID)
    }

    private var hasUnsavedChanges: Bool {
        savedCharacterID != selectedCharacterID || savedClipID != selectedClipID
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
                    charactersSection
                    sayingsSection
                    actionButtons
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
        }
    }

    // MARK: - Top bar

    private var topBar: some View {
        HStack(spacing: 12) {
            LockInBackPill(action: { dismiss() }, label: "Home")
            Spacer()
            PillBadge(text: "Voice", style: .neutral, systemImage: "waveform")
        }
    }

    // MARK: - Header

    private var header: some View {
        VStack(alignment: .leading, spacing: 8) {
            LockInType.screenTitle("Choose Your Voice")
            LockInType.screenSubtitle("Pick the character that yells at you when you start drifting.")
        }
    }

    // MARK: - Permission warning

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

    // MARK: - Characters

    private var charactersSection: some View {
        VStack(alignment: .leading, spacing: LockInSpacing.m) {
            SectionHeader(title: "Voices", trailing: "\(characters.count) characters")
            VStack(spacing: 10) {
                ForEach(characters) { character in
                    Button {
                        selectCharacter(character)
                    } label: {
                        CharacterCard(
                            character: character,
                            isSelected: character.id == selectedCharacterID
                        )
                    }
                    .buttonStyle(PressableScaleStyle())
                }
            }
        }
    }

    // MARK: - Sayings

    private var sayingsSection: some View {
        VStack(alignment: .leading, spacing: LockInSpacing.m) {
            SectionHeader(title: "Sayings", trailing: selectedCharacter.name)
            VStack(spacing: 8) {
                ForEach(selectedCharacter.clips) { clip in
                    Button {
                        selectedClipID = clip.id
                    } label: {
                        ClipRow(
                            clip: clip,
                            accent: selectedCharacter.accent,
                            isSelected: clip.id == selectedClipID
                        )
                    }
                    .buttonStyle(PressableScaleStyle())
                }
            }
        }
    }

    // MARK: - Actions

    private var actionButtons: some View {
        VStack(spacing: 10) {
            PrimaryButton(
                title: "Preview",
                systemImage: "play.fill",
                style: .secondary
            ) {
                Task { await handleSendPreview() }
            }

            PrimaryButton(
                title: hasUnsavedChanges ? "Save Voice" : "Voice saved",
                systemImage: hasUnsavedChanges ? "tray.and.arrow.down.fill" : "checkmark.seal.fill",
                style: .primary,
                isEnabled: hasUnsavedChanges
            ) {
                saveSelection()
            }
        }
    }

    // MARK: - Logic

    private func selectCharacter(_ character: VoiceCharacter) {
        selectedCharacterID = character.id
        if let firstClip = character.clips.first {
            // If switching characters, pick their first saying by default.
            if !(selectedClipID.hasPrefix(character.id + ".")) {
                selectedClipID = firstClip.id
            }
        }
    }

    private func saveSelection() {
        let clip = selectedClip
        savedCharacterID = clip.characterId
        savedClipID = clip.id
        showStatus("Saved. \(selectedCharacter.name) — \u{201C}\(clip.notificationText)\u{201D}")
    }

    private func handleSendPreview() async {
        switch notificationManager.authState {
        case .unknown:
            let granted = await notificationManager.requestNotificationPermission()
            guard granted else {
                showStatus("Enable notifications in Settings to preview alerts.")
                return
            }
        case .denied:
            showStatus("Notifications are off. Enable them in Settings.")
            return
        case .authorized:
            break
        }

        let scheduled = await notificationManager.sendTestNotification(clip: selectedClip, after: 3)
        if scheduled {
            showStatus("Preview in 3 seconds. Lock or background your phone to hear it.")
        } else {
            showStatus("Could not schedule preview. Check notification permissions.")
        }
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

// MARK: - Character card

private struct CharacterCard: View {
    let character: VoiceCharacter
    let isSelected: Bool

    var body: some View {
        HStack(alignment: .top, spacing: 14) {
            ZStack {
                RoundedRectangle(cornerRadius: 12, style: .continuous)
                    .fill(character.accent.opacity(isSelected ? 0.35 : 0.18))
                    .frame(width: 48, height: 48)
                Image(systemName: "waveform")
                    .font(.system(size: 20, weight: .bold))
                    .foregroundStyle(.white)
            }

            VStack(alignment: .leading, spacing: 8) {
                HStack(spacing: 8) {
                    Text(character.name)
                        .font(.system(size: 17, weight: .bold, design: .rounded))
                        .foregroundStyle(LockInColor.textPrimary)
                    if character.isPremium {
                        PillBadge(text: "Premium", style: .premium, systemImage: "crown.fill")
                    }
                    Spacer(minLength: 0)
                    if isSelected {
                        Image(systemName: "checkmark.circle.fill")
                            .font(.system(size: 18, weight: .bold))
                            .foregroundStyle(LockInColor.accent)
                    }
                }

                Text(character.archetype.uppercased())
                    .font(.system(size: 10, weight: .heavy, design: .rounded))
                    .tracking(1.4)
                    .foregroundStyle(character.accent)

                Text(character.shortDescription)
                    .font(.system(size: 13.5, weight: .medium, design: .rounded))
                    .foregroundStyle(LockInColor.textSecondary)
                    .fixedSize(horizontal: false, vertical: true)

                if !character.toneTags.isEmpty {
                    HStack(spacing: 6) {
                        ForEach(character.toneTags.prefix(3), id: \.self) { tag in
                            PillBadge(text: tag, style: .custom(character.accent))
                        }
                    }
                }
            }
        }
        .padding(14)
        .frame(maxWidth: .infinity, alignment: .leading)
        .background(
            RoundedRectangle(cornerRadius: LockInRadius.l, style: .continuous)
                .fill(isSelected ? LockInColor.surfaceElevated : LockInColor.surface)
        )
        .overlay(
            RoundedRectangle(cornerRadius: LockInRadius.l, style: .continuous)
                .strokeBorder(
                    isSelected ? character.accent.opacity(0.65) : LockInColor.border,
                    lineWidth: isSelected ? 1.4 : 1
                )
        )
    }
}

// MARK: - Clip row

private struct ClipRow: View {
    let clip: VoiceClip
    let accent: Color
    let isSelected: Bool

    var body: some View {
        HStack(spacing: 12) {
            Image(systemName: isSelected ? "largecircle.fill.circle" : "circle")
                .font(.system(size: 18, weight: isSelected ? .bold : .regular))
                .foregroundStyle(isSelected ? accent : LockInColor.textTertiary)

            VStack(alignment: .leading, spacing: 2) {
                Text(clip.sayingTitle)
                    .font(.system(size: 14, weight: .bold, design: .rounded))
                    .foregroundStyle(LockInColor.textPrimary)
                Text("\u{201C}\(clip.notificationText)\u{201D}")
                    .font(.system(size: 13, weight: .medium, design: .rounded))
                    .foregroundStyle(LockInColor.textSecondary)
                    .lineLimit(2)
                    .fixedSize(horizontal: false, vertical: true)
            }

            Spacer(minLength: 0)

            IntensityIndicator(level: clip.intensityLevel, accent: accent)
        }
        .padding(12)
        .frame(maxWidth: .infinity, alignment: .leading)
        .background(
            RoundedRectangle(cornerRadius: LockInRadius.m, style: .continuous)
                .fill(isSelected ? LockInColor.surfaceElevated : LockInColor.surface)
        )
        .overlay(
            RoundedRectangle(cornerRadius: LockInRadius.m, style: .continuous)
                .strokeBorder(
                    isSelected ? accent.opacity(0.55) : LockInColor.border,
                    lineWidth: isSelected ? 1.2 : 1
                )
        )
    }
}

private struct IntensityIndicator: View {
    let level: Int
    let accent: Color

    var body: some View {
        HStack(spacing: 3) {
            ForEach(0..<5, id: \.self) { i in
                Capsule()
                    .fill(i < level ? accent : LockInColor.border)
                    .frame(width: 3, height: 12 + CGFloat(i) * 2)
            }
        }
    }
}

#Preview {
    NavigationStack {
        AlertSetupView()
    }
    .preferredColorScheme(.dark)
}
