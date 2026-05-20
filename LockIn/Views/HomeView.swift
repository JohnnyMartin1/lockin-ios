//
//  HomeView.swift
//  LockIn
//
//  Created by Catherine Fratila on 5/20/26.
//

import SwiftUI

struct HomeView: View {
    @AppStorage(SelectedAlertKeys.voiceName) private var savedVoiceName: String = ""
    @AppStorage(SelectedAlertKeys.sayingTitle) private var savedSayingTitle: String = ""
    @AppStorage(SelectedAlertKeys.notificationText) private var savedNotificationText: String = ""
    @AppStorage(SelectedLimitKeys.minutes) private var savedLimitMinutes: Int = LockInLimitOption.defaultMinutes

    private var savedLimitOption: LockInLimitOption {
        LockInLimitOption.option(forMinutes: savedLimitMinutes)
    }

    var body: some View {
        NavigationStack {
            ZStack {
                backgroundLayer.ignoresSafeArea()

                ScrollView {
                    VStack(alignment: .leading, spacing: 28) {
                        header
                        summarySection
                        cardGrid
                        footerNote
                    }
                    .padding(.horizontal, 24)
                    .padding(.top, 24)
                    .padding(.bottom, 48)
                    .frame(maxWidth: .infinity, alignment: .leading)
                }
            }
            .toolbar(.hidden, for: .navigationBar)
        }
    }

    // MARK: - Summary

    private var summarySection: some View {
        VStack(spacing: 12) {
            if !savedVoiceName.isEmpty {
                currentAlertCard
            }
            currentLimitCard
        }
    }

    // MARK: - Background

    private var backgroundLayer: some View {
        ZStack {
            Color.black
            RadialGradient(
                colors: [
                    Color(red: 0.85, green: 0.10, blue: 0.20).opacity(0.35),
                    Color.black.opacity(0)
                ],
                center: .topTrailing,
                startRadius: 20,
                endRadius: 420
            )
            RadialGradient(
                colors: [
                    Color(red: 0.30, green: 0.10, blue: 0.45).opacity(0.25),
                    Color.black.opacity(0)
                ],
                center: .bottomLeading,
                startRadius: 20,
                endRadius: 500
            )
        }
    }

    // MARK: - Header

    private var header: some View {
        VStack(alignment: .leading, spacing: 10) {
            HStack(spacing: 10) {
                Image(systemName: "lock.shield.fill")
                    .font(.system(size: 22, weight: .bold))
                    .foregroundStyle(
                        LinearGradient(
                            colors: [Color.red, Color.orange],
                            startPoint: .topLeading,
                            endPoint: .bottomTrailing
                        )
                    )
                Text("LOCKIN")
                    .font(.system(size: 14, weight: .heavy, design: .rounded))
                    .tracking(4)
                    .foregroundStyle(.white.opacity(0.65))
            }

            Text("LockIn")
                .font(.system(size: 56, weight: .black, design: .rounded))
                .foregroundStyle(.white)

            Text("Loud accountability for doomscrolling.")
                .font(.system(size: 17, weight: .medium, design: .rounded))
                .foregroundStyle(.white.opacity(0.7))
        }
    }

    // MARK: - Current alert card

    private var currentAlertCard: some View {
        NavigationLink {
            AlertSetupView()
        } label: {
            HStack(alignment: .center, spacing: 14) {
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

                VStack(alignment: .leading, spacing: 4) {
                    Text("YOUR ALERT")
                        .font(.system(size: 11, weight: .heavy, design: .rounded))
                        .tracking(1.8)
                        .foregroundStyle(.white.opacity(0.55))
                    Text(savedVoiceName)
                        .font(.system(size: 17, weight: .bold, design: .rounded))
                        .foregroundStyle(.white)
                    if !savedNotificationText.isEmpty {
                        Text("\u{201C}\(savedNotificationText)\u{201D}")
                            .font(.system(size: 13, weight: .medium, design: .rounded))
                            .foregroundStyle(.white.opacity(0.7))
                            .lineLimit(1)
                    }
                }

                Spacer(minLength: 0)

                Image(systemName: "chevron.right")
                    .font(.system(size: 14, weight: .bold))
                    .foregroundStyle(.white.opacity(0.45))
            }
            .padding(16)
            .frame(maxWidth: .infinity, alignment: .leading)
            .background(
                RoundedRectangle(cornerRadius: 20, style: .continuous)
                    .fill(Color.white.opacity(0.06))
            )
            .overlay(
                RoundedRectangle(cornerRadius: 20, style: .continuous)
                    .strokeBorder(Color.white.opacity(0.10), lineWidth: 1)
            )
        }
        .buttonStyle(PressableScaleStyle())
    }

    // MARK: - Current limit card

    private var currentLimitCard: some View {
        NavigationLink {
            LimitSetupView()
        } label: {
            HStack(alignment: .center, spacing: 14) {
                ZStack {
                    RoundedRectangle(cornerRadius: 12, style: .continuous)
                        .fill(
                            LinearGradient(
                                colors: [
                                    Color(red: 0.30, green: 0.10, blue: 0.45),
                                    Color(red: 0.85, green: 0.10, blue: 0.20)
                                ],
                                startPoint: .topLeading,
                                endPoint: .bottomTrailing
                            )
                        )
                        .frame(width: 46, height: 46)
                    Image(systemName: "timer")
                        .font(.system(size: 20, weight: .bold))
                        .foregroundStyle(.white)
                }

                VStack(alignment: .leading, spacing: 4) {
                    Text("YOUR LIMIT")
                        .font(.system(size: 11, weight: .heavy, design: .rounded))
                        .tracking(1.8)
                        .foregroundStyle(.white.opacity(0.55))
                    Text(savedLimitOption.longLabel)
                        .font(.system(size: 17, weight: .bold, design: .rounded))
                        .foregroundStyle(.white)
                    Text("Before LockIn yells at you.")
                        .font(.system(size: 13, weight: .medium, design: .rounded))
                        .foregroundStyle(.white.opacity(0.7))
                        .lineLimit(1)
                }

                Spacer(minLength: 0)

                Image(systemName: "chevron.right")
                    .font(.system(size: 14, weight: .bold))
                    .foregroundStyle(.white.opacity(0.45))
            }
            .padding(16)
            .frame(maxWidth: .infinity, alignment: .leading)
            .background(
                RoundedRectangle(cornerRadius: 20, style: .continuous)
                    .fill(Color.white.opacity(0.06))
            )
            .overlay(
                RoundedRectangle(cornerRadius: 20, style: .continuous)
                    .strokeBorder(Color.white.opacity(0.10), lineWidth: 1)
            )
        }
        .buttonStyle(PressableScaleStyle())
    }

    // MARK: - Card grid

    private var cardGrid: some View {
        LazyVGrid(
            columns: [
                GridItem(.flexible(), spacing: 16),
                GridItem(.flexible(), spacing: 16)
            ],
            spacing: 16
        ) {
            Button {
            } label: {
                ActionCard(
                    title: "Pick Apps",
                    subtitle: "Choose what distracts you",
                    systemImage: "apps.iphone",
                    style: .neutral
                )
            }
            .buttonStyle(PressableScaleStyle())

            NavigationLink {
                LimitSetupView()
            } label: {
                ActionCard(
                    title: "Set Limit",
                    subtitle: "How long is too long?",
                    systemImage: "timer",
                    style: .neutral
                )
            }
            .buttonStyle(PressableScaleStyle())

            NavigationLink {
                AlertSetupView()
            } label: {
                ActionCard(
                    title: "Customize Alert",
                    subtitle: "Pick your wake-up call",
                    systemImage: "speaker.wave.3.fill",
                    style: .neutral
                )
            }
            .buttonStyle(PressableScaleStyle())

            Button {
            } label: {
                ActionCard(
                    title: "Start LockIn",
                    subtitle: "Hold yourself accountable",
                    systemImage: "bolt.fill",
                    style: .primary
                )
            }
            .buttonStyle(PressableScaleStyle())
        }
    }

    // MARK: - Footer

    private var footerNote: some View {
        Text("No accounts. No tracking. Just you and your screen time.")
            .font(.footnote)
            .foregroundStyle(.white.opacity(0.4))
            .frame(maxWidth: .infinity, alignment: .center)
            .padding(.top, 8)
    }
}

// MARK: - Action card (visual)

private struct ActionCard: View {
    enum Style {
        case neutral
        case primary
    }

    let title: String
    let subtitle: String
    let systemImage: String
    let style: Style

    var body: some View {
        VStack(alignment: .leading, spacing: 14) {
            ZStack {
                RoundedRectangle(cornerRadius: 12, style: .continuous)
                    .fill(iconBackground)
                    .frame(width: 44, height: 44)
                Image(systemName: systemImage)
                    .font(.system(size: 20, weight: .bold))
                    .foregroundStyle(.white)
            }

            Spacer(minLength: 0)

            VStack(alignment: .leading, spacing: 4) {
                Text(title)
                    .font(.system(size: 18, weight: .bold, design: .rounded))
                    .foregroundStyle(.white)
                Text(subtitle)
                    .font(.system(size: 13, weight: .medium, design: .rounded))
                    .foregroundStyle(subtitleColor)
                    .lineLimit(2)
                    .fixedSize(horizontal: false, vertical: true)
            }
        }
        .padding(18)
        .frame(maxWidth: .infinity, minHeight: 160, alignment: .topLeading)
        .background(cardBackground)
        .overlay(
            RoundedRectangle(cornerRadius: 20, style: .continuous)
                .strokeBorder(borderColor, lineWidth: 1)
        )
        .clipShape(RoundedRectangle(cornerRadius: 20, style: .continuous))
    }

    @ViewBuilder
    private var cardBackground: some View {
        switch style {
        case .neutral:
            Color.white.opacity(0.06)
        case .primary:
            LinearGradient(
                colors: [
                    Color(red: 0.95, green: 0.18, blue: 0.30),
                    Color(red: 0.65, green: 0.08, blue: 0.20)
                ],
                startPoint: .topLeading,
                endPoint: .bottomTrailing
            )
        }
    }

    private var borderColor: Color {
        switch style {
        case .neutral: return .white.opacity(0.08)
        case .primary: return .white.opacity(0.15)
        }
    }

    private var iconBackground: Color {
        switch style {
        case .neutral: return .white.opacity(0.10)
        case .primary: return .white.opacity(0.18)
        }
    }

    private var subtitleColor: Color {
        switch style {
        case .neutral: return .white.opacity(0.55)
        case .primary: return .white.opacity(0.85)
        }
    }
}

#Preview {
    HomeView()
        .preferredColorScheme(.dark)
}
