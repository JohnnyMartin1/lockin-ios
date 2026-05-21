//
//  ModeSetupView.swift
//  LockIn
//

import SwiftUI

struct ModeSetupView: View {
    @Environment(\.dismiss) private var dismiss

    @AppStorage(LockInSetupKeys.modeType) private var savedModeRaw: String = ""

    @State private var selection: LockInModeType?
    @State private var chainToLimits = false

    init() {
        let raw = UserDefaults.standard.string(forKey: LockInSetupKeys.modeType) ?? ""
        _selection = State(initialValue: LockInModeType(rawValue: raw))
    }

    private var hasUnsavedChanges: Bool {
        selection?.rawValue != savedModeRaw
    }

    var body: some View {
        ZStack {
            LockInBackground()

            ScrollView {
                VStack(alignment: .leading, spacing: LockInSpacing.xl) {
                    topBar
                    header
                    modeCards
                    continueButton
                }
                .padding(.horizontal, LockInSpacing.xl)
                .padding(.top, LockInSpacing.s)
                .padding(.bottom, LockInSpacing.xxxl)
            }

            // Invisible link used to chain into LimitSetupView on Save.
            NavigationLink(value: chainToLimits) { EmptyView() }
                .hidden()
        }
        .navigationBarBackButtonHidden(true)
        .toolbar(.hidden, for: .navigationBar)
        .navigationDestination(isPresented: $chainToLimits) {
            LimitSetupView()
        }
    }

    // MARK: - Sections

    private var topBar: some View {
        HStack(spacing: 12) {
            LockInBackPill(action: { dismiss() }, label: "Home")
            Spacer()
            PillBadge(text: "Mode", style: .neutral, systemImage: "switch.2")
        }
    }

    private var header: some View {
        VStack(alignment: .leading, spacing: 8) {
            LockInType.screenTitle("How should LockIn work?")
            LockInType.screenSubtitle("Pick one. You can change it any time.")
        }
    }

    private var modeCards: some View {
        VStack(spacing: 10) {
            ForEach(LockInModeType.allCases) { mode in
                Button {
                    selection = mode
                } label: {
                    ModeCard(mode: mode, isSelected: selection == mode)
                }
                .buttonStyle(PressableScaleStyle())
            }
        }
    }

    private var continueButton: some View {
        PrimaryButton(
            title: selection == nil ? "Pick a mode" : (hasUnsavedChanges ? "Save & Continue" : "Continue"),
            systemImage: "arrow.right",
            style: .primary,
            isEnabled: selection != nil
        ) {
            saveAndContinue()
        }
    }

    // MARK: - Logic

    private func saveAndContinue() {
        guard let mode = selection else { return }
        if savedModeRaw != mode.rawValue {
            savedModeRaw = mode.rawValue
        }
        SetupSyncCoordinator.syncCurrentSetupToSharedStore()
        chainToLimits = true
    }
}

// MARK: - Mode card

private struct ModeCard: View {
    let mode: LockInModeType
    let isSelected: Bool

    var body: some View {
        HStack(alignment: .top, spacing: 14) {
            ZStack {
                RoundedRectangle(cornerRadius: 12, style: .continuous)
                    .fill(LockInColor.accent.opacity(isSelected ? 0.22 : 0.12))
                    .frame(width: 44, height: 44)
                Image(systemName: mode.systemImage)
                    .font(.system(size: 18, weight: .semibold))
                    .foregroundStyle(isSelected ? LockInColor.accent : LockInColor.textSecondary)
            }

            VStack(alignment: .leading, spacing: 6) {
                HStack(spacing: 8) {
                    Text(mode.displayName)
                        .font(.system(size: 16, weight: .bold, design: .rounded))
                        .foregroundStyle(LockInColor.textPrimary)
                    Spacer(minLength: 0)
                    if isSelected {
                        Image(systemName: "checkmark.circle.fill")
                            .font(.system(size: 18, weight: .bold))
                            .foregroundStyle(LockInColor.accent)
                    }
                }

                Text(mode.tagline)
                    .font(.system(size: 13.5, weight: .medium, design: .rounded))
                    .foregroundStyle(LockInColor.textSecondary)
                    .fixedSize(horizontal: false, vertical: true)
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
                    isSelected ? LockInColor.accent.opacity(0.55) : LockInColor.border,
                    lineWidth: isSelected ? 1.3 : 1
                )
        )
    }
}

#Preview {
    NavigationStack {
        ModeSetupView()
    }
    .preferredColorScheme(.dark)
}
