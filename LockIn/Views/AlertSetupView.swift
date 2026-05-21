//
//  AlertSetupView.swift
//  LockIn
//

import SwiftUI

struct AlertSetupView: View {
    @StateObject private var notificationManager = NotificationManager.shared
    @Environment(\.dismiss) private var dismiss

    @AppStorage(SelectedVoiceKeys.characterId) private var savedCharacterID: String = ""
    @AppStorage(SelectedVoiceKeys.clipIds)     private var savedClipIDsRaw: String  = ""
    @AppStorage(LockInSetupKeys.randomizeSayings) private var savedShuffle: Bool    = LockInDefaults.randomizeSayings

    @State private var selectedCharacterID: String
    @State private var selectedClipIDs: Set<String>
    @State private var draftShuffle: Bool
    @State private var statusMessage: String?
    @State private var hasRequestedPermission = false

    private let characters = VoiceLibrary.characters

    init() {
        let storedCharacter = UserDefaults.standard.string(forKey: SelectedVoiceKeys.characterId) ?? ""
        let storedClips     = UserDefaults.standard.string(forKey: SelectedVoiceKeys.clipIds) ?? ""
        let storedShuffle   = UserDefaults.standard.object(forKey: LockInSetupKeys.randomizeSayings) as? Bool
            ?? LockInDefaults.randomizeSayings

        let parsedClips = Set(SelectedClipsStorage.decode(storedClips))
        let resolvedCharacter = VoiceLibrary.character(withID: storedCharacter) ?? VoiceLibrary.defaultCharacter

        // If no clips are saved yet, seed with the character's first clip so
        // the user always has something selected and can save immediately.
        let initialClips: Set<String>
        if parsedClips.isEmpty {
            initialClips = Set(resolvedCharacter.clips.first.map { [$0.id] } ?? [])
        } else {
            // Drop any saved clip IDs that don't belong to the resolved character.
            initialClips = Set(parsedClips.compactMap { id in
                VoiceLibrary.clip(withID: id)?.characterId == resolvedCharacter.id ? id : nil
            })
        }

        _selectedCharacterID = State(initialValue: resolvedCharacter.id)
        _selectedClipIDs     = State(initialValue: initialClips)
        _draftShuffle        = State(initialValue: storedShuffle)
    }

    // MARK: - Derived

    private var selectedCharacter: VoiceCharacter {
        VoiceLibrary.character(withID: selectedCharacterID) ?? VoiceLibrary.defaultCharacter
    }

    /// Currently selected clips, in the canonical character order.
    private var selectedClips: [VoiceClip] {
        selectedCharacter.clips.filter { selectedClipIDs.contains($0.id) }
    }

    private var orderedSelectedClipIDs: [String] {
        selectedClips.map(\.id)
    }

    private var hasUnsavedChanges: Bool {
        let saved = Set(SelectedClipsStorage.decode(savedClipIDsRaw))
        return savedCharacterID != selectedCharacterID
            || saved != selectedClipIDs
            || savedShuffle != draftShuffle
    }

    private var canSave: Bool {
        !selectedClipIDs.isEmpty
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
                    shuffleToggle
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

    // MARK: - Top bar / header

    private var topBar: some View {
        HStack(spacing: 12) {
            LockInBackPill(action: { dismiss() }, label: "Home")
            Spacer()
            PillBadge(text: "Voice", style: .neutral, systemImage: "waveform")
        }
    }

    private var header: some View {
        VStack(alignment: .leading, spacing: 8) {
            LockInType.screenTitle("Choose Your Character")
            LockInType.screenSubtitle("Pick who yells at you when time is up.")
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

    // MARK: - Characters

    private var charactersSection: some View {
        VStack(alignment: .leading, spacing: LockInSpacing.m) {
            SectionHeader(title: "Characters")
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

    // MARK: - Sayings (multi-select)

    private var sayingsSection: some View {
        VStack(alignment: .leading, spacing: LockInSpacing.m) {
            SectionHeader(
                title: "Sayings",
                trailing: "\(selectedCharacter.name) · \(selectedClipIDs.count) picked"
            )
            VStack(spacing: 8) {
                ForEach(selectedCharacter.clips) { clip in
                    Button {
                        toggleClip(clip.id)
                    } label: {
                        ClipRow(
                            clip: clip,
                            accent: selectedCharacter.accent,
                            isSelected: selectedClipIDs.contains(clip.id)
                        )
                    }
                    .buttonStyle(PressableScaleStyle())
                }
            }
        }
    }

    // MARK: - Shuffle

    private var shuffleToggle: some View {
        HStack(spacing: 12) {
            Image(systemName: "shuffle")
                .font(.system(size: 14, weight: .semibold))
                .foregroundStyle(LockInColor.textSecondary)
                .frame(width: 22)
            VStack(alignment: .leading, spacing: 2) {
                Text("Shuffle sayings")
                    .font(.system(size: 14.5, weight: .bold, design: .rounded))
                    .foregroundStyle(LockInColor.textPrimary)
                Text(shuffleSubtitle)
                    .font(.system(size: 12.5, weight: .medium, design: .rounded))
                    .foregroundStyle(LockInColor.textSecondary)
                    .fixedSize(horizontal: false, vertical: true)
            }
            Spacer(minLength: 0)
            Toggle("", isOn: $draftShuffle)
                .labelsHidden()
                .tint(LockInColor.accent)
        }
        .padding(14)
        .frame(maxWidth: .infinity, alignment: .leading)
        .background(
            RoundedRectangle(cornerRadius: LockInRadius.m, style: .continuous)
                .fill(LockInColor.surface)
        )
        .overlay(
            RoundedRectangle(cornerRadius: LockInRadius.m, style: .continuous)
                .strokeBorder(LockInColor.border, lineWidth: 1)
        )
    }

    private var shuffleSubtitle: String {
        if selectedClipIDs.count <= 1 {
            return "Pick more than one saying to enable shuffle."
        }
        return draftShuffle
            ? "LockIn picks a random saying each time."
            : "LockIn uses the same saying each time."
    }

    // MARK: - Actions

    private var actionButtons: some View {
        VStack(spacing: 10) {
            PrimaryButton(
                title: "Send Test Alert",
                systemImage: "play.fill",
                style: .secondary,
                isEnabled: canSave
            ) {
                Task { await handleSendPreview() }
            }

            PrimaryButton(
                title: hasUnsavedChanges ? "Save Alert" : "Alert saved",
                systemImage: hasUnsavedChanges ? "tray.and.arrow.down.fill" : "checkmark.seal.fill",
                style: .primary,
                isEnabled: hasUnsavedChanges && canSave
            ) {
                saveSelection()
            }
        }
    }

    // MARK: - Logic

    private func selectCharacter(_ character: VoiceCharacter) {
        guard character.id != selectedCharacterID else { return }
        selectedCharacterID = character.id
        // Reset to that character's first saying when switching characters.
        if let firstClip = character.clips.first {
            selectedClipIDs = [firstClip.id]
        } else {
            selectedClipIDs = []
        }
    }

    private func toggleClip(_ id: String) {
        if selectedClipIDs.contains(id) {
            if selectedClipIDs.count > 1 {
                selectedClipIDs.remove(id)
            }
            // Keep at least one selection — silently ignore if this is the last.
        } else {
            selectedClipIDs.insert(id)
        }
    }

    private func saveSelection() {
        guard canSave else { return }
        savedCharacterID = selectedCharacterID
        savedClipIDsRaw  = SelectedClipsStorage.encode(orderedSelectedClipIDs)
        savedShuffle     = draftShuffle
        SetupSyncCoordinator.syncCurrentSetupToSharedStore()
        let n = selectedClipIDs.count
        let suffix = (n > 1 && draftShuffle) ? " (shuffle on)" : ""
        showStatus("Saved. \(selectedCharacter.name) · \(n) saying\(n == 1 ? "" : "s")\(suffix).")
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

        let candidates = selectedClips
        let scheduled = await notificationManager.sendTestNotification(
            candidates: candidates,
            shuffle: draftShuffle,
            after: 3
        )
        if scheduled {
            showStatus("Preview in 3 seconds. Lock or background your phone to hear it.")
        } else {
            showStatus("Could not schedule preview. Pick at least one saying.")
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
                    .frame(width: 44, height: 44)
                Image(systemName: "waveform")
                    .font(.system(size: 18, weight: .bold))
                    .foregroundStyle(.white)
            }

            VStack(alignment: .leading, spacing: 6) {
                HStack(spacing: 8) {
                    Text(character.name)
                        .font(.system(size: 16, weight: .bold, design: .rounded))
                        .foregroundStyle(LockInColor.textPrimary)
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
                    .font(.system(size: 13, weight: .medium, design: .rounded))
                    .foregroundStyle(LockInColor.textSecondary)
                    .fixedSize(horizontal: false, vertical: true)
            }
        }
        .padding(12)
        .frame(maxWidth: .infinity, alignment: .leading)
        .background(
            RoundedRectangle(cornerRadius: LockInRadius.l, style: .continuous)
                .fill(isSelected ? LockInColor.surfaceElevated : LockInColor.surface)
        )
        .overlay(
            RoundedRectangle(cornerRadius: LockInRadius.l, style: .continuous)
                .strokeBorder(
                    isSelected ? character.accent.opacity(0.65) : LockInColor.border,
                    lineWidth: isSelected ? 1.3 : 1
                )
        )
    }
}

// MARK: - Clip row (checkbox-style multi-select)

private struct ClipRow: View {
    let clip: VoiceClip
    let accent: Color
    let isSelected: Bool

    var body: some View {
        HStack(spacing: 12) {
            Image(systemName: isSelected ? "checkmark.square.fill" : "square")
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
        }
        .padding(.vertical, 11)
        .padding(.horizontal, 12)
        .frame(maxWidth: .infinity, alignment: .leading)
        .background(
            RoundedRectangle(cornerRadius: LockInRadius.m, style: .continuous)
                .fill(isSelected ? LockInColor.surfaceElevated : LockInColor.surface)
        )
        .overlay(
            RoundedRectangle(cornerRadius: LockInRadius.m, style: .continuous)
                .strokeBorder(
                    isSelected ? accent.opacity(0.45) : LockInColor.border,
                    lineWidth: isSelected ? 1.2 : 1
                )
        )
    }
}

#Preview {
    NavigationStack {
        AlertSetupView()
    }
    .preferredColorScheme(.dark)
}
