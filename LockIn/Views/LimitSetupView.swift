//
//  LimitSetupView.swift
//  LockIn
//
//  Created by Catherine Fratila on 5/20/26.
//

import SwiftUI

struct LimitSetupView: View {
    @Environment(\.dismiss) private var dismiss

    @AppStorage(SelectedLimitKeys.minutes) private var savedLimitMinutes: Int = LockInLimitOption.defaultMinutes
    @AppStorage(SelectedAlertKeys.voiceName) private var savedVoiceName: String = ""

    @State private var selectedMinutes: Int
    @State private var statusMessage: String?

    private let options = LockInLimitOption.options

    init() {
        let stored = UserDefaults.standard.object(forKey: SelectedLimitKeys.minutes) as? Int
            ?? LockInLimitOption.defaultMinutes
        _selectedMinutes = State(initialValue: stored)
    }

    private var selectedOption: LockInLimitOption {
        LockInLimitOption.option(forMinutes: selectedMinutes)
    }

    private var hasUnsavedChanges: Bool {
        selectedMinutes != savedLimitMinutes
    }

    var body: some View {
        ZStack {
            backgroundLayer.ignoresSafeArea()

            ScrollView {
                VStack(alignment: .leading, spacing: 28) {
                    topBar
                    header
                    limitGrid
                    summaryCard
                    saveButton
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
    }

    // MARK: - Background

    private var backgroundLayer: some View {
        ZStack {
            Color.black
            RadialGradient(
                colors: [
                    Color(red: 0.95, green: 0.18, blue: 0.30).opacity(0.28),
                    Color.black.opacity(0)
                ],
                center: .topLeading,
                startRadius: 20,
                endRadius: 460
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

            Text("LIMIT")
                .font(.system(size: 12, weight: .heavy, design: .rounded))
                .tracking(3)
                .foregroundStyle(.white.opacity(0.55))
        }
    }

    // MARK: - Header

    private var header: some View {
        VStack(alignment: .leading, spacing: 10) {
            Text("Set Your Doomscroll Limit")
                .font(.system(size: 32, weight: .black, design: .rounded))
                .foregroundStyle(.white)
                .fixedSize(horizontal: false, vertical: true)

            Text("Pick how long you get before LockIn yells at you.")
                .font(.system(size: 16, weight: .medium, design: .rounded))
                .foregroundStyle(.white.opacity(0.65))
                .fixedSize(horizontal: false, vertical: true)
        }
    }

    // MARK: - Limit grid

    private var limitGrid: some View {
        VStack(alignment: .leading, spacing: 12) {
            Text("CHOOSE A LIMIT")
                .font(.system(size: 12, weight: .heavy, design: .rounded))
                .tracking(2.5)
                .foregroundStyle(.white.opacity(0.55))

            LazyVGrid(
                columns: [
                    GridItem(.flexible(), spacing: 12),
                    GridItem(.flexible(), spacing: 12),
                    GridItem(.flexible(), spacing: 12)
                ],
                spacing: 12
            ) {
                ForEach(options) { option in
                    Button {
                        selectedMinutes = option.minutes
                    } label: {
                        LimitOptionCell(
                            option: option,
                            isSelected: option.minutes == selectedMinutes
                        )
                    }
                    .buttonStyle(PressableScaleStyle())
                }
            }
        }
    }

    // MARK: - Summary card

    private var summaryCard: some View {
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
                        Image(systemName: "timer")
                            .font(.system(size: 20, weight: .bold))
                            .foregroundStyle(.white)
                    }

                    VStack(alignment: .leading, spacing: 2) {
                        Text("Current limit: \(selectedOption.longLabel)")
                            .font(.system(size: 18, weight: .bold, design: .rounded))
                            .foregroundStyle(.white)
                            .fixedSize(horizontal: false, vertical: true)
                        Text(selectedOption.caption.uppercased())
                            .font(.system(size: 11, weight: .heavy, design: .rounded))
                            .tracking(1.8)
                            .foregroundStyle(.white.opacity(0.55))
                    }

                    Spacer(minLength: 0)
                }

                Divider()
                    .background(Color.white.opacity(0.08))

                HStack(alignment: .top, spacing: 12) {
                    Image(systemName: "megaphone.fill")
                        .font(.system(size: 14, weight: .bold))
                        .foregroundStyle(Color.orange)
                        .frame(width: 22)
                    Text(alertCopy)
                        .font(.system(size: 14, weight: .medium, design: .rounded))
                        .foregroundStyle(.white.opacity(0.80))
                        .fixedSize(horizontal: false, vertical: true)
                    Spacer(minLength: 0)
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

    private var alertCopy: String {
        if savedVoiceName.isEmpty {
            return "When you hit this, your selected LockIn alert will fire."
        }
        return "When you hit this, \(savedVoiceName) will fire your LockIn alert."
    }

    // MARK: - Save button

    private var saveButton: some View {
        Button {
            saveSelection()
        } label: {
            HStack(spacing: 10) {
                Image(systemName: hasUnsavedChanges ? "tray.and.arrow.down.fill" : "checkmark.seal.fill")
                    .font(.system(size: 16, weight: .bold))
                Text(hasUnsavedChanges ? "Save Limit" : "Limit saved.")
                    .font(.system(size: 17, weight: .bold, design: .rounded))
            }
            .foregroundStyle(.white)
            .frame(maxWidth: .infinity)
            .padding(.vertical, 16)
            .background(buttonBackground)
            .clipShape(RoundedRectangle(cornerRadius: 16, style: .continuous))
            .overlay(
                RoundedRectangle(cornerRadius: 16, style: .continuous)
                    .strokeBorder(Color.white.opacity(0.18), lineWidth: 1)
            )
        }
        .buttonStyle(PressableScaleStyle())
        .disabled(!hasUnsavedChanges)
    }

    @ViewBuilder
    private var buttonBackground: some View {
        if hasUnsavedChanges {
            LinearGradient(
                colors: [
                    Color(red: 0.95, green: 0.18, blue: 0.30),
                    Color(red: 0.65, green: 0.08, blue: 0.20)
                ],
                startPoint: .topLeading,
                endPoint: .bottomTrailing
            )
        } else {
            Color.white.opacity(0.08)
        }
    }

    // MARK: - Status banner

    private func statusBanner(_ message: String) -> some View {
        HStack(alignment: .top, spacing: 12) {
            Image(systemName: "checkmark.seal.fill")
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
        savedLimitMinutes = selectedMinutes
        showStatus("Limit saved. \(selectedOption.longLabel) before LockIn yells at you.")
    }

    private func showStatus(_ message: String) {
        withAnimation(.easeOut(duration: 0.2)) {
            statusMessage = message
        }
        Task {
            try? await Task.sleep(nanoseconds: 4_000_000_000)
            await MainActor.run {
                withAnimation(.easeOut(duration: 0.2)) {
                    statusMessage = nil
                }
            }
        }
    }
}

// MARK: - Limit option cell

private struct LimitOptionCell: View {
    let option: LockInLimitOption
    let isSelected: Bool

    var body: some View {
        VStack(spacing: 6) {
            Text(numberText)
                .font(.system(size: 26, weight: .black, design: .rounded))
                .foregroundStyle(.white)
                .lineLimit(1)
                .minimumScaleFactor(0.6)

            Text(unitText)
                .font(.system(size: 11, weight: .heavy, design: .rounded))
                .tracking(1.5)
                .foregroundStyle(unitColor)
        }
        .frame(maxWidth: .infinity)
        .padding(.vertical, 18)
        .background(
            RoundedRectangle(cornerRadius: 18, style: .continuous)
                .fill(cardFill)
        )
        .overlay(
            RoundedRectangle(cornerRadius: 18, style: .continuous)
                .strokeBorder(borderColor, lineWidth: isSelected ? 1.5 : 1)
        )
        .overlay(alignment: .topTrailing) {
            if isSelected {
                Image(systemName: "checkmark.circle.fill")
                    .font(.system(size: 16, weight: .bold))
                    .foregroundStyle(
                        LinearGradient(
                            colors: [Color.red, Color.orange],
                            startPoint: .topLeading,
                            endPoint: .bottomTrailing
                        )
                    )
                    .padding(8)
            }
        }
        .shadow(
            color: isSelected
                ? Color(red: 0.95, green: 0.18, blue: 0.30).opacity(0.35)
                : Color.clear,
            radius: 14,
            x: 0,
            y: 6
        )
    }

    private var numberText: String {
        option.minutes >= 60 ? "\(option.minutes / 60)" : "\(option.minutes)"
    }

    private var unitText: String {
        if option.minutes >= 60 {
            return option.minutes == 60 ? "HOUR" : "HOURS"
        }
        return option.minutes == 1 ? "MIN" : "MIN"
    }

    private var cardFill: Color {
        isSelected ? Color.white.opacity(0.10) : Color.white.opacity(0.05)
    }

    private var borderColor: Color {
        isSelected
            ? Color(red: 0.95, green: 0.18, blue: 0.30).opacity(0.85)
            : Color.white.opacity(0.08)
    }

    private var unitColor: Color {
        isSelected
            ? Color(red: 1.0, green: 0.55, blue: 0.40)
            : .white.opacity(0.55)
    }
}

#Preview {
    NavigationStack {
        LimitSetupView()
    }
    .preferredColorScheme(.dark)
}
