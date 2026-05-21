//
//  HomeView.swift
//  LockIn
//

import SwiftUI

struct HomeView: View {
    @AppStorage(SelectedAppsKeys.ids) private var savedAppIDsRaw: String = ""
    @AppStorage(SelectedLimitKeys.minutes) private var savedLimitMinutes: Int = LockInLimitOption.defaultMinutes
    @AppStorage(SelectedVoiceKeys.characterId) private var savedCharacterID: String = ""
    @AppStorage(SelectedVoiceKeys.clipId) private var savedClipID: String = ""

    private var selectedAppCount: Int {
        SelectedAppsStorage.decode(savedAppIDsRaw).count
    }

    private var selectedLimit: LockInLimitOption {
        LockInLimitOption.option(forMinutes: savedLimitMinutes)
    }

    private var selectedCharacter: VoiceCharacter {
        VoiceLibrary.character(withID: savedCharacterID) ?? VoiceLibrary.defaultCharacter
    }

    private var selectedClip: VoiceClip {
        VoiceLibrary.resolveClip(characterID: savedCharacterID, clipID: savedClipID)
    }

    private var appsValueLabel: String {
        switch selectedAppCount {
        case 0: return "No apps selected"
        case 1: return "1 app selected"
        default: return "\(selectedAppCount) apps selected"
        }
    }

    var body: some View {
        NavigationStack {
            ZStack {
                LockInBackground()

                ScrollView {
                    VStack(alignment: .leading, spacing: LockInSpacing.xl) {
                        headerSection
                        currentSetupCard
                        startCTA
                        setupRows
                        footerNote
                    }
                    .padding(.horizontal, LockInSpacing.xl)
                    .padding(.top, LockInSpacing.xxl)
                    .padding(.bottom, LockInSpacing.xxxl)
                }
            }
            .toolbar(.hidden, for: .navigationBar)
        }
    }

    // MARK: - Header

    private var headerSection: some View {
        VStack(alignment: .leading, spacing: 8) {
            LockInType.wordmark("LOCKIN", size: 22)
            Text("Your screen-time wake-up call.")
                .font(.system(size: 14, weight: .medium, design: .rounded))
                .foregroundStyle(LockInColor.textSecondary)
        }
        .padding(.top, LockInSpacing.s)
    }

    // MARK: - Current setup

    private var currentSetupCard: some View {
        VStack(alignment: .leading, spacing: LockInSpacing.l) {
            SectionHeader(title: "Current Setup", trailing: "Today")

            VStack(spacing: 0) {
                SetupSummaryRow(
                    label: "Character",
                    value: selectedCharacter.name,
                    systemImage: "waveform",
                    accent: selectedCharacter.accent,
                    trailingIcon: nil
                )
                .padding(.vertical, 12)

                Divider().overlay(LockInColor.border)

                SetupSummaryRow(
                    label: "Saying",
                    value: selectedClip.sayingTitle,
                    systemImage: "quote.bubble",
                    accent: LockInColor.textSecondary,
                    trailingIcon: nil
                )
                .padding(.vertical, 12)

                Divider().overlay(LockInColor.border)

                SetupSummaryRow(
                    label: "Limit",
                    value: selectedLimit.longLabel,
                    systemImage: "timer",
                    accent: LockInColor.textSecondary,
                    trailingIcon: nil
                )
                .padding(.vertical, 12)

                Divider().overlay(LockInColor.border)

                SetupSummaryRow(
                    label: "Apps",
                    value: appsValueLabel,
                    systemImage: "apps.iphone",
                    accent: LockInColor.textSecondary,
                    trailingIcon: nil
                )
                .padding(.vertical, 12)
            }
        }
        .padding(LockInSpacing.l)
        .frame(maxWidth: .infinity, alignment: .leading)
        .background(
            RoundedRectangle(cornerRadius: LockInRadius.l, style: .continuous)
                .fill(LockInColor.surface)
        )
        .overlay(
            RoundedRectangle(cornerRadius: LockInRadius.l, style: .continuous)
                .strokeBorder(LockInColor.border, lineWidth: 1)
        )
    }

    // MARK: - Primary CTA

    private var startCTA: some View {
        NavigationLink {
            StartLockInView()
        } label: {
            HStack(spacing: 12) {
                Image(systemName: "bolt.fill")
                    .font(.system(size: 17, weight: .bold))
                Text("Start LockIn")
                    .font(.system(size: 18, weight: .bold, design: .rounded))
                Spacer()
                Image(systemName: "arrow.right")
                    .font(.system(size: 14, weight: .bold))
                    .foregroundStyle(.white.opacity(0.7))
            }
            .foregroundStyle(.white)
            .padding(.vertical, 20)
            .padding(.horizontal, 22)
            .frame(maxWidth: .infinity)
            .background(LockInColor.accent)
            .clipShape(RoundedRectangle(cornerRadius: LockInRadius.l, style: .continuous))
            .overlay(
                RoundedRectangle(cornerRadius: LockInRadius.l, style: .continuous)
                    .strokeBorder(Color.white.opacity(0.10), lineWidth: 1)
            )
        }
        .buttonStyle(PressableScaleStyle())
    }

    // MARK: - Setup rows

    private var setupRows: some View {
        VStack(alignment: .leading, spacing: LockInSpacing.m) {
            SectionHeader(title: "Setup")

            VStack(spacing: 10) {
                NavigationLink {
                    AppSelectionView()
                } label: {
                    SetupRowCard(
                        title: "Apps",
                        subtitle: appsValueLabel,
                        systemImage: "apps.iphone",
                        accent: LockInColor.textSecondary
                    )
                }
                .buttonStyle(PressableScaleStyle())

                NavigationLink {
                    LimitSetupView()
                } label: {
                    SetupRowCard(
                        title: "Limit",
                        subtitle: selectedLimit.longLabel,
                        systemImage: "timer",
                        accent: LockInColor.textSecondary
                    )
                }
                .buttonStyle(PressableScaleStyle())

                NavigationLink {
                    AlertSetupView()
                } label: {
                    SetupRowCard(
                        title: "Voice",
                        subtitle: "\(selectedCharacter.name) — \(selectedClip.sayingTitle)",
                        systemImage: "waveform",
                        accent: selectedCharacter.accent
                    )
                }
                .buttonStyle(PressableScaleStyle())
            }
        }
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

// MARK: - Setup row card

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
                    .frame(width: 40, height: 40)
                Image(systemName: systemImage)
                    .font(.system(size: 16, weight: .semibold))
                    .foregroundStyle(accent)
            }

            VStack(alignment: .leading, spacing: 2) {
                Text(title)
                    .font(.system(size: 16, weight: .bold, design: .rounded))
                    .foregroundStyle(LockInColor.textPrimary)
                Text(subtitle)
                    .font(.system(size: 13, weight: .medium, design: .rounded))
                    .foregroundStyle(LockInColor.textSecondary)
                    .lineLimit(1)
            }

            Spacer(minLength: 0)

            Image(systemName: "chevron.right")
                .font(.system(size: 13, weight: .semibold))
                .foregroundStyle(LockInColor.textTertiary)
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
}

#Preview {
    HomeView()
        .preferredColorScheme(.dark)
}
