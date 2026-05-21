//
//  LimitSetupView.swift
//  LockIn
//

import SwiftUI

struct LimitSetupView: View {
    @Environment(\.dismiss) private var dismiss

    @AppStorage(SelectedLimitKeys.minutes) private var savedLimitMinutes: Int = LockInLimitOption.defaultMinutes

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
            LockInBackground()

            ScrollView {
                VStack(alignment: .leading, spacing: LockInSpacing.xl) {
                    topBar
                    header
                    limitGrid
                    previewCard
                    saveButton
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
    }

    private var topBar: some View {
        HStack(spacing: 12) {
            LockInBackPill(action: { dismiss() }, label: "Home")
            Spacer()
            PillBadge(text: "Limit", style: .neutral, systemImage: "timer")
        }
    }

    private var header: some View {
        VStack(alignment: .leading, spacing: 8) {
            LockInType.screenTitle("Your Limit")
            LockInType.screenSubtitle("How long you get before LockIn fires.")
        }
    }

    private var limitGrid: some View {
        VStack(alignment: .leading, spacing: LockInSpacing.m) {
            SectionHeader(title: "Choose a Limit")
            LazyVGrid(
                columns: [
                    GridItem(.flexible(), spacing: LockInSpacing.m),
                    GridItem(.flexible(), spacing: LockInSpacing.m),
                    GridItem(.flexible(), spacing: LockInSpacing.m)
                ],
                spacing: LockInSpacing.m
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

    private var previewCard: some View {
        VStack(alignment: .leading, spacing: LockInSpacing.m) {
            SectionHeader(title: "Preview")
            LockInCard {
                VStack(alignment: .leading, spacing: 10) {
                    HStack(alignment: .firstTextBaseline, spacing: 6) {
                        Text(selectedOption.longLabel)
                            .font(.system(size: 22, weight: .heavy, design: .rounded))
                            .foregroundStyle(LockInColor.textPrimary)
                        Text(selectedOption.caption)
                            .font(.system(size: 13, weight: .medium, design: .rounded))
                            .foregroundStyle(LockInColor.textTertiary)
                    }
                    Text("LockIn will fire after this much time in your selected apps.")
                        .font(.system(size: 13, weight: .medium, design: .rounded))
                        .foregroundStyle(LockInColor.textSecondary)
                        .fixedSize(horizontal: false, vertical: true)
                }
            }
        }
    }

    private var saveButton: some View {
        PrimaryButton(
            title: hasUnsavedChanges ? "Save Limit" : "Limit saved",
            systemImage: hasUnsavedChanges ? "tray.and.arrow.down.fill" : "checkmark.seal.fill",
            style: .primary,
            isEnabled: hasUnsavedChanges
        ) {
            saveSelection()
        }
    }

    private func saveSelection() {
        savedLimitMinutes = selectedMinutes
        showStatus("Limit saved. \(selectedOption.longLabel).")
    }

    private func showStatus(_ message: String) {
        withAnimation(.easeOut(duration: 0.2)) { statusMessage = message }
        Task {
            try? await Task.sleep(nanoseconds: 4_000_000_000)
            await MainActor.run {
                withAnimation(.easeOut(duration: 0.2)) { statusMessage = nil }
            }
        }
    }
}

private struct LimitOptionCell: View {
    let option: LockInLimitOption
    let isSelected: Bool

    var body: some View {
        VStack(spacing: 4) {
            Text(numberText)
                .font(.system(size: 26, weight: .black, design: .rounded))
                .foregroundStyle(LockInColor.textPrimary)
                .lineLimit(1)
                .minimumScaleFactor(0.6)

            Text(unitText)
                .font(.system(size: 10, weight: .heavy, design: .rounded))
                .tracking(1.4)
                .foregroundStyle(isSelected ? LockInColor.accent : LockInColor.textTertiary)
        }
        .frame(maxWidth: .infinity)
        .padding(.vertical, 16)
        .background(
            RoundedRectangle(cornerRadius: LockInRadius.m, style: .continuous)
                .fill(isSelected ? LockInColor.surfaceElevated : LockInColor.surface)
        )
        .overlay(
            RoundedRectangle(cornerRadius: LockInRadius.m, style: .continuous)
                .strokeBorder(
                    isSelected ? LockInColor.accent.opacity(0.55) : LockInColor.border,
                    lineWidth: isSelected ? 1.2 : 1
                )
        )
    }

    private var numberText: String {
        option.minutes >= 60 ? "\(option.minutes / 60)" : "\(option.minutes)"
    }

    private var unitText: String {
        if option.minutes >= 60 {
            return option.minutes == 60 ? "HOUR" : "HOURS"
        }
        return "MIN"
    }
}

#Preview {
    NavigationStack {
        LimitSetupView()
    }
    .preferredColorScheme(.dark)
}
