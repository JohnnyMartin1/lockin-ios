//
//  LimitSetupView.swift
//  LockIn
//
//  Mode-aware limit / session / slip-threshold setup.
//

import SwiftUI

struct LimitSetupView: View {
    @Environment(\.dismiss) private var dismiss

    @AppStorage(LockInSetupKeys.modeType) private var savedModeRaw: String = ""
    @AppStorage(LockInSetupKeys.dailyLimitMinutes)    private var dailyLimitMinutes: Int    = LockInDefaults.dailyLimitMinutes
    @AppStorage(LockInSetupKeys.sessionLengthMinutes) private var sessionLengthMinutes: Int = LockInDefaults.sessionLengthMinutes
    @AppStorage(LockInSetupKeys.slipThresholdSeconds) private var slipThresholdSeconds: Int = LockInDefaults.slipThresholdSeconds

    @State private var draftDailyLimit: Int
    @State private var draftSessionLength: Int
    @State private var draftSlipThreshold: Int
    @State private var statusMessage: String?

    private var mode: LockInModeType? {
        LockInModeType(rawValue: savedModeRaw)
    }

    init() {
        let dl = (UserDefaults.standard.object(forKey: LockInSetupKeys.dailyLimitMinutes) as? Int)    ?? LockInDefaults.dailyLimitMinutes
        let sl = (UserDefaults.standard.object(forKey: LockInSetupKeys.sessionLengthMinutes) as? Int) ?? LockInDefaults.sessionLengthMinutes
        let st = (UserDefaults.standard.object(forKey: LockInSetupKeys.slipThresholdSeconds) as? Int) ?? LockInDefaults.slipThresholdSeconds
        _draftDailyLimit    = State(initialValue: dl)
        _draftSessionLength = State(initialValue: sl)
        _draftSlipThreshold = State(initialValue: st)
    }

    private var hasUnsavedChanges: Bool {
        switch mode {
        case .some(.dailyLimit):
            return draftDailyLimit != dailyLimitMinutes
        case .some(.lockInSession):
            return draftSessionLength != sessionLengthMinutes
                || draftSlipThreshold != slipThresholdSeconds
        case .none:
            return false
        }
    }

    var body: some View {
        ZStack {
            LockInBackground()

            ScrollView {
                VStack(alignment: .leading, spacing: LockInSpacing.xl) {
                    topBar
                    header
                    switch mode {
                    case .some(.dailyLimit):     dailySection
                    case .some(.lockInSession):  sessionSections
                    case .none:                  noModeCard
                    }
                    if mode != nil {
                        saveButton
                    }
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

    // MARK: - Top bar / header

    private var topBar: some View {
        HStack(spacing: 12) {
            LockInBackPill(action: { dismiss() }, label: "Back")
            Spacer()
            PillBadge(
                text: mode?.displayName ?? "No mode",
                style: .neutral,
                systemImage: mode?.systemImage ?? "questionmark.circle"
            )
        }
    }

    private var header: some View {
        VStack(alignment: .leading, spacing: 8) {
            LockInType.screenTitle(headerTitle)
            LockInType.screenSubtitle(headerSubtitle)
        }
    }

    private var headerTitle: String {
        switch mode {
        case .some(.dailyLimit):    return "Set Daily Limit"
        case .some(.lockInSession): return "Set LockIn Rules"
        case .none:                 return "Pick a Mode First"
        }
    }

    private var headerSubtitle: String {
        switch mode {
        case .some(.dailyLimit):
            return "How much time do you get on these apps each day?"
        case .some(.lockInSession):
            return "Choose your focus window and how long you can slip before LockIn fires."
        case .none:
            return "Head back to Mode to choose Daily Limit or LockIn Mode."
        }
    }

    // MARK: - Daily section

    private var dailySection: some View {
        VStack(alignment: .leading, spacing: LockInSpacing.m) {
            SectionHeader(title: "Daily Limit")
            limitGrid(values: LockInOptions.dailyLimitMinutes,
                      selected: draftDailyLimit) { v in
                draftDailyLimit = v
            } label: { v in
                LimitFormatter.shortMinutes(v)
            }
        }
    }

    // MARK: - Session sections

    private var sessionSections: some View {
        VStack(alignment: .leading, spacing: LockInSpacing.xl) {
            VStack(alignment: .leading, spacing: LockInSpacing.m) {
                SectionHeader(title: "Session Length")
                limitGrid(values: LockInOptions.sessionLengthMinutes,
                          selected: draftSessionLength) { v in
                    draftSessionLength = v
                } label: { v in
                    LimitFormatter.shortMinutes(v)
                }
            }

            VStack(alignment: .leading, spacing: LockInSpacing.m) {
                SectionHeader(title: "Slip Threshold")
                limitGrid(values: LockInOptions.slipThresholdSeconds,
                          selected: draftSlipThreshold) { v in
                    draftSlipThreshold = v
                } label: { v in
                    LimitFormatter.shortSeconds(v)
                }
            }
        }
    }

    // MARK: - No mode

    private var noModeCard: some View {
        LockInCard {
            HStack(spacing: 12) {
                Image(systemName: "switch.2")
                    .font(.system(size: 18, weight: .semibold))
                    .foregroundStyle(LockInColor.textSecondary)
                    .frame(width: 28)
                Text("Choose a mode on the Mode screen to set your limits.")
                    .font(.system(size: 14, weight: .medium, design: .rounded))
                    .foregroundStyle(LockInColor.textSecondary)
                    .fixedSize(horizontal: false, vertical: true)
                Spacer(minLength: 0)
            }
        }
    }

    // MARK: - Grid

    @ViewBuilder
    private func limitGrid(
        values: [Int],
        selected: Int,
        onSelect: @escaping (Int) -> Void,
        label: @escaping (Int) -> String
    ) -> some View {
        LazyVGrid(
            columns: Array(
                repeating: GridItem(.flexible(), spacing: LockInSpacing.m),
                count: values.count >= 4 ? 4 : values.count
            ),
            spacing: LockInSpacing.m
        ) {
            ForEach(values, id: \.self) { v in
                Button {
                    onSelect(v)
                } label: {
                    LimitChip(label: label(v), isSelected: v == selected)
                }
                .buttonStyle(PressableScaleStyle())
            }
        }
    }

    // MARK: - Save

    private var saveButton: some View {
        PrimaryButton(
            title: hasUnsavedChanges ? "Save" : "Saved",
            systemImage: hasUnsavedChanges ? "tray.and.arrow.down.fill" : "checkmark.seal.fill",
            style: .primary,
            isEnabled: hasUnsavedChanges
        ) {
            saveSelection()
        }
    }

    private func saveSelection() {
        switch mode {
        case .some(.dailyLimit):
            dailyLimitMinutes = draftDailyLimit
            showStatus("Saved. \(LimitFormatter.minutes(draftDailyLimit)) per day.")
        case .some(.lockInSession):
            sessionLengthMinutes = draftSessionLength
            slipThresholdSeconds = draftSlipThreshold
            showStatus("Saved. \(LimitFormatter.minutes(draftSessionLength)) session, \(LimitFormatter.seconds(draftSlipThreshold)) slip.")
        case .none:
            return
        }
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

// MARK: - Limit chip

private struct LimitChip: View {
    let label: String
    let isSelected: Bool

    var body: some View {
        Text(label)
            .font(.system(size: 16, weight: .bold, design: .rounded))
            .foregroundStyle(LockInColor.textPrimary)
            .frame(maxWidth: .infinity)
            .padding(.vertical, 14)
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
}

#Preview {
    NavigationStack {
        LimitSetupView()
    }
    .preferredColorScheme(.dark)
}
