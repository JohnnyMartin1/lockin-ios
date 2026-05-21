//
//  HomeView.swift
//  LockIn
//

import SwiftUI

struct HomeView: View {
    @AppStorage(LockInSetupKeys.modeType)              private var modeRaw: String           = ""
    @AppStorage(LockInSetupKeys.dailyLimitMinutes)     private var dailyLimitMinutes: Int    = LockInDefaults.dailyLimitMinutes
    @AppStorage(LockInSetupKeys.sessionLengthMinutes)  private var sessionLengthMinutes: Int = LockInDefaults.sessionLengthMinutes
    @AppStorage(LockInSetupKeys.slipThresholdSeconds)  private var slipThresholdSeconds: Int = LockInDefaults.slipThresholdSeconds
    @AppStorage(LockInSetupKeys.appGroupID)            private var appGroupID: String        = ""
    @AppStorage(LockInSetupKeys.randomizeSayings)      private var shuffleSayings: Bool      = LockInDefaults.randomizeSayings
    @AppStorage(SelectedAppsKeys.ids)                  private var savedAppIDsRaw: String    = ""
    @AppStorage(SelectedVoiceKeys.characterId)         private var savedCharacterID: String  = ""
    @AppStorage(SelectedVoiceKeys.clipIds)             private var savedClipIDsRaw: String   = ""

    // MARK: - Derived

    private var mode: LockInModeType? { LockInModeType(rawValue: modeRaw) }

    private var selectedAppIDs: [String] {
        SelectedAppsStorage.decode(savedAppIDsRaw)
    }

    private var selectedClipIDs: [String] {
        SelectedClipsStorage.decode(savedClipIDsRaw)
    }

    private var selectedCharacter: VoiceCharacter? {
        VoiceLibrary.character(withID: savedCharacterID)
    }

    private var resolvedCharacter: VoiceCharacter {
        selectedCharacter ?? VoiceLibrary.defaultCharacter
    }

    private var matchedGroup: LockInAppGroup? {
        guard !appGroupID.isEmpty,
              let group = LockInAppGroup.group(withID: appGroupID),
              Set(group.appIDs) == Set(selectedAppIDs) else { return nil }
        return group
    }

    private var appsValueLabel: String {
        if let group = matchedGroup {
            return "\(group.name) · \(selectedAppIDs.count)"
        }
        switch selectedAppIDs.count {
        case 0: return "Not set"
        case 1: return "1 app selected"
        default: return "\(selectedAppIDs.count) apps selected"
        }
    }

    private var limitValueLabel: String {
        switch mode {
        case .some(.dailyLimit):
            return "\(LimitFormatter.minutes(dailyLimitMinutes)) per day"
        case .some(.lockInSession):
            return "\(LimitFormatter.minutes(sessionLengthMinutes)) · \(LimitFormatter.shortSeconds(slipThresholdSeconds)) slip"
        case .none:
            return "Not set"
        }
    }

    private var characterValueLabel: String {
        selectedCharacter?.name ?? "Not set"
    }

    private var sayingsCountValueLabel: String {
        let n = selectedClipIDs.count
        switch n {
        case 0: return "Not set"
        case 1: return "1 saying"
        default:
            return shuffleSayings ? "\(n) sayings · shuffle" : "\(n) sayings"
        }
    }

    private var isSetupComplete: Bool {
        mode != nil && !selectedAppIDs.isEmpty && !selectedClipIDs.isEmpty
    }

    var body: some View {
        NavigationStack {
            ZStack {
                LockInBackground()

                ScrollView {
                    VStack(alignment: .leading, spacing: LockInSpacing.xl) {
                        headerSection
                        currentSetupCard
                        primaryCTA
                        setupRows
                        footerNote
                    }
                    .padding(.horizontal, LockInSpacing.xl)
                    .padding(.top, LockInSpacing.l)
                    .padding(.bottom, LockInSpacing.xxxl)
                }
            }
            .toolbar(.hidden, for: .navigationBar)
        }
    }

    // MARK: - Header

    private var headerSection: some View {
        VStack(alignment: .leading, spacing: 6) {
            LockInType.wordmark("LOCKIN")
            Text("Your screen-time wake-up call.")
                .font(.system(size: 13.5, weight: .medium, design: .rounded))
                .foregroundStyle(LockInColor.textSecondary)
        }
        .padding(.top, LockInSpacing.s)
    }

    // MARK: - Current setup

    private var currentSetupCard: some View {
        VStack(alignment: .leading, spacing: LockInSpacing.m) {
            SectionHeader(title: "Current Setup")
            LockInCard {
                VStack(spacing: 0) {
                    ForEach(Array(rows.enumerated()), id: \.offset) { (i, row) in
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
    }

    private struct Row {
        let label: String
        let value: String
        let icon: String
        let accent: Color
    }

    private var rows: [Row] {
        [
            Row(label: "Mode",
                value: mode?.displayName ?? "Not set",
                icon: mode?.systemImage ?? "switch.2",
                accent: LockInColor.textSecondary),
            Row(label: "Apps",
                value: appsValueLabel,
                icon: "apps.iphone",
                accent: LockInColor.textSecondary),
            Row(label: "Limit",
                value: limitValueLabel,
                icon: "timer",
                accent: LockInColor.textSecondary),
            Row(label: "Character",
                value: characterValueLabel,
                icon: "waveform",
                accent: selectedCharacter?.accent ?? LockInColor.textSecondary),
            Row(label: "Sayings",
                value: sayingsCountValueLabel,
                icon: "quote.bubble",
                accent: LockInColor.textSecondary)
        ]
    }

    // MARK: - Primary CTA

    @ViewBuilder
    private var primaryCTA: some View {
        if isSetupComplete {
            NavigationLink {
                StartLockInView()
            } label: {
                CTAButtonLabel(title: "Start LockIn", systemImage: "bolt.fill")
            }
            .buttonStyle(PressableScaleStyle())
        } else {
            NavigationLink {
                ModeSetupView()
            } label: {
                CTAButtonLabel(title: "Set Up LockIn", systemImage: "arrow.right")
            }
            .buttonStyle(PressableScaleStyle())
        }
    }

    // MARK: - Setup rows (Mode / Apps / Voice)

    private var setupRows: some View {
        VStack(alignment: .leading, spacing: LockInSpacing.m) {
            SectionHeader(title: "Setup")

            VStack(spacing: 8) {
                NavigationLink {
                    ModeSetupView()
                } label: {
                    SetupRowCard(
                        title: "Mode",
                        subtitle: mode?.displayName ?? "Not set",
                        systemImage: mode?.systemImage ?? "switch.2"
                    )
                }
                .buttonStyle(PressableScaleStyle())

                NavigationLink {
                    AppSelectionView()
                } label: {
                    SetupRowCard(
                        title: "Apps",
                        subtitle: appsValueLabel,
                        systemImage: "apps.iphone"
                    )
                }
                .buttonStyle(PressableScaleStyle())

                NavigationLink {
                    AlertSetupView()
                } label: {
                    SetupRowCard(
                        title: "Voice",
                        subtitle: voiceSubtitle,
                        systemImage: "waveform",
                        accent: selectedCharacter?.accent ?? LockInColor.textSecondary
                    )
                }
                .buttonStyle(PressableScaleStyle())
            }
        }
    }

    private var voiceSubtitle: String {
        guard let character = selectedCharacter, !selectedClipIDs.isEmpty else {
            return "Not set"
        }
        let n = selectedClipIDs.count
        if n == 1 {
            if let clip = VoiceLibrary.clip(withID: selectedClipIDs[0]) {
                return "\(character.name) · \(clip.sayingTitle)"
            }
            return character.name
        }
        return "\(character.name) · \(n) sayings\(shuffleSayings ? " · shuffle" : "")"
    }

    // MARK: - Footer

    private var footerNote: some View {
        Text("No accounts. No tracking. Just you and your screen time.")
            .font(.system(size: 12, weight: .medium, design: .rounded))
            .foregroundStyle(LockInColor.textMuted)
            .frame(maxWidth: .infinity, alignment: .center)
            .padding(.top, LockInSpacing.m)
    }
}

// MARK: - Local helpers

private struct CTAButtonLabel: View {
    let title: String
    let systemImage: String

    var body: some View {
        HStack(spacing: 10) {
            Image(systemName: systemImage)
                .font(.system(size: 16, weight: .bold))
            Text(title)
                .font(.system(size: 17, weight: .bold, design: .rounded))
            Spacer()
            Image(systemName: "arrow.right")
                .font(.system(size: 13, weight: .bold))
                .foregroundStyle(.white.opacity(0.7))
        }
        .foregroundStyle(.white)
        .padding(.vertical, 18)
        .padding(.horizontal, 20)
        .frame(maxWidth: .infinity)
        .background(LockInColor.accent)
        .clipShape(RoundedRectangle(cornerRadius: LockInRadius.l, style: .continuous))
        .overlay(
            RoundedRectangle(cornerRadius: LockInRadius.l, style: .continuous)
                .strokeBorder(Color.white.opacity(0.10), lineWidth: 1)
        )
    }
}

private struct SetupRowCard: View {
    let title: String
    let subtitle: String
    let systemImage: String
    var accent: Color = LockInColor.textSecondary

    var body: some View {
        HStack(spacing: 14) {
            ZStack {
                RoundedRectangle(cornerRadius: 10, style: .continuous)
                    .fill(accent.opacity(0.16))
                    .frame(width: 38, height: 38)
                Image(systemName: systemImage)
                    .font(.system(size: 15, weight: .semibold))
                    .foregroundStyle(accent)
            }

            VStack(alignment: .leading, spacing: 2) {
                Text(title)
                    .font(.system(size: 15.5, weight: .bold, design: .rounded))
                    .foregroundStyle(LockInColor.textPrimary)
                Text(subtitle)
                    .font(.system(size: 12.5, weight: .medium, design: .rounded))
                    .foregroundStyle(LockInColor.textSecondary)
                    .lineLimit(1)
            }

            Spacer(minLength: 0)

            Image(systemName: "chevron.right")
                .font(.system(size: 12, weight: .semibold))
                .foregroundStyle(LockInColor.textTertiary)
        }
        .padding(.vertical, 11)
        .padding(.horizontal, 12)
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
}

#Preview {
    HomeView()
        .preferredColorScheme(.dark)
}
