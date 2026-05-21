//
//  AppSelectionView.swift
//  LockIn
//
//  Phase A: Real Screen Time selection (FamilyActivityPicker) is the primary
//  path when authorized. Mock "Preview Mode" remains as a fallback for
//  development, simulator runs, and demos. No DeviceActivity monitoring yet.
//

import FamilyControls
import SwiftUI

struct AppSelectionView: View {
    @Environment(\.dismiss) private var dismiss

    // Real Screen Time
    @StateObject private var screenTime  = ScreenTimeManager.shared
    @StateObject private var familyStore = FamilySelectionStore.shared

    // Preview Mode (mock)
    @AppStorage(SelectedAppsKeys.ids)       private var savedAppIDsRaw: String   = ""
    @AppStorage(LockInSetupKeys.appGroupID) private var savedAppGroupID: String  = ""

    @State private var selectedMockIDs: Set<String>
    @State private var statusMessage: String?
    @State private var isPickerPresented = false
    @State private var isRequestingAuth = false
    @State private var selectionBeforePicker: FamilyActivitySelection?

    private let apps   = MockApp.bundled
    private let groups = LockInAppGroup.presets

    init() {
        let raw = UserDefaults.standard.string(forKey: SelectedAppsKeys.ids) ?? ""
        _selectedMockIDs = State(initialValue: Set(SelectedAppsStorage.decode(raw)))
    }

    // MARK: - Derived

    private var isApproved: Bool { screenTime.authState.isApproved }

    private var savedMockIDs: Set<String> { Set(SelectedAppsStorage.decode(savedAppIDsRaw)) }

    private var currentGroupMatch: LockInAppGroup? {
        LockInAppGroup.match(forSelectedAppIDs: Array(selectedMockIDs))
    }

    private var hasUnsavedMockChanges: Bool {
        savedMockIDs != selectedMockIDs
            || savedAppGroupID != (currentGroupMatch?.id ?? "")
    }

    private var headerTitle: String {
        isApproved ? "Apps to Watch" : "Enable App Selection"
    }

    private var headerSubtitle: String {
        if isApproved {
            return "Choose the apps LockIn should watch."
        }
        return "LockIn needs Screen Time access so you can choose the apps you want to manage."
    }

    private var topBarPillText: String {
        if isApproved && familyStore.hasAnySelection {
            return "\(familyStore.totalCount) picked"
        }
        if !selectedMockIDs.isEmpty {
            return "Preview \u{00B7} \(selectedMockIDs.count)"
        }
        return "Nothing picked"
    }

    // MARK: - Body

    var body: some View {
        ZStack {
            LockInBackground()

            ScrollView {
                VStack(alignment: .leading, spacing: LockInSpacing.xl) {
                    topBar
                    header
                    if isApproved {
                        realSelectionSection
                    } else {
                        enableScreenTimeSection
                    }
                    previewModeSection
                    screenTimeNote
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
        .familyActivityPicker(isPresented: $isPickerPresented, selection: $familyStore.selection)
        .onChange(of: isPickerPresented) { _, newValue in
            if !newValue, let snapshot = selectionBeforePicker {
                if snapshot != familyStore.selection {
                    showStatus("Selection saved.")
                }
                selectionBeforePicker = nil
            }
        }
        .onAppear {
            // Re-read in case the user just toggled Screen Time in Settings.
            screenTime.refreshAuthorizationStatus()
        }
    }

    // MARK: - Top bar / header

    private var topBar: some View {
        HStack(spacing: 12) {
            LockInBackPill(action: { dismiss() }, label: "Home")
            Spacer()
            PillBadge(
                text: topBarPillText,
                style: isApproved && familyStore.hasAnySelection ? .accent : .neutral,
                systemImage: "checkmark.seal.fill"
            )
        }
    }

    private var header: some View {
        VStack(alignment: .leading, spacing: 8) {
            LockInType.screenTitle(headerTitle)
            LockInType.screenSubtitle(headerSubtitle)
        }
    }

    // MARK: - Enable Screen Time (not approved)

    private var enableScreenTimeSection: some View {
        LockInCard {
            VStack(alignment: .leading, spacing: 14) {
                HStack(spacing: 12) {
                    ZStack {
                        RoundedRectangle(cornerRadius: 10, style: .continuous)
                            .fill(LockInColor.accent.opacity(0.18))
                            .frame(width: 40, height: 40)
                        Image(systemName: "hand.raised.fill")
                            .font(.system(size: 16, weight: .semibold))
                            .foregroundStyle(LockInColor.accent)
                    }
                    VStack(alignment: .leading, spacing: 2) {
                        Text("Screen Time Access")
                            .font(.system(size: 15, weight: .bold, design: .rounded))
                            .foregroundStyle(LockInColor.textPrimary)
                        Text(authHint)
                            .font(.system(size: 12.5, weight: .medium, design: .rounded))
                            .foregroundStyle(LockInColor.textSecondary)
                            .fixedSize(horizontal: false, vertical: true)
                    }
                    Spacer(minLength: 0)
                }

                PrimaryButton(
                    title: isRequestingAuth ? "Requesting\u{2026}" : "Enable Screen Time Access",
                    systemImage: "checkmark.shield.fill",
                    style: .primary,
                    isEnabled: !isRequestingAuth
                ) {
                    Task { await requestScreenTime() }
                }

                if case .error(let msg) = screenTime.authState {
                    Text("Couldn't enable: \(msg)")
                        .font(.system(size: 11.5, weight: .medium, design: .rounded))
                        .foregroundStyle(LockInColor.warning)
                        .fixedSize(horizontal: false, vertical: true)
                } else if screenTime.authState == .denied {
                    Text("Access was denied. You can still use Preview Mode below, or re-enable Screen Time for LockIn in iOS Settings.")
                        .font(.system(size: 11.5, weight: .medium, design: .rounded))
                        .foregroundStyle(LockInColor.warning)
                        .fixedSize(horizontal: false, vertical: true)
                }
            }
        }
    }

    private var authHint: String {
        switch screenTime.authState {
        case .notDetermined: return "Tap to allow LockIn to read your Screen Time usage."
        case .approved:      return "Granted."
        case .denied:        return "Denied. Re-enable in iOS Settings."
        case .error:         return "Try again or use Preview Mode below."
        }
    }

    // MARK: - Real selection (approved)

    private var realSelectionSection: some View {
        VStack(alignment: .leading, spacing: LockInSpacing.m) {
            SectionHeader(title: "Screen Time Selection", trailing: "Recommended")
            LockInCard {
                VStack(alignment: .leading, spacing: 14) {
                    HStack(spacing: 12) {
                        ZStack {
                            RoundedRectangle(cornerRadius: 10, style: .continuous)
                                .fill(LockInColor.accent.opacity(0.18))
                                .frame(width: 40, height: 40)
                            Image(systemName: "checkmark.seal.fill")
                                .font(.system(size: 16, weight: .semibold))
                                .foregroundStyle(LockInColor.accent)
                        }
                        VStack(alignment: .leading, spacing: 2) {
                            Text(familyStore.hasAnySelection ? "Apps selected" : "Nothing selected yet")
                                .font(.system(size: 15, weight: .bold, design: .rounded))
                                .foregroundStyle(LockInColor.textPrimary)
                            Text(familyStore.summary)
                                .font(.system(size: 12.5, weight: .medium, design: .rounded))
                                .foregroundStyle(LockInColor.textSecondary)
                                .fixedSize(horizontal: false, vertical: true)
                        }
                        Spacer(minLength: 0)
                    }

                    Text("Apple keeps your selection private. LockIn sees secure tokens, not specific app names.")
                        .font(.system(size: 11.5, weight: .medium, design: .rounded))
                        .foregroundStyle(LockInColor.textTertiary)
                        .fixedSize(horizontal: false, vertical: true)

                    HStack(spacing: 10) {
                        PrimaryButton(
                            title: familyStore.hasAnySelection ? "Edit Selection" : "Choose Apps",
                            systemImage: "apps.iphone",
                            style: .primary
                        ) {
                            presentPicker()
                        }
                        if familyStore.hasAnySelection {
                            PrimaryButton(
                                title: "Clear",
                                systemImage: "xmark.circle",
                                style: .secondary
                            ) {
                                familyStore.clear()
                                showStatus("Selection cleared.")
                            }
                        }
                    }
                }
            }
        }
    }

    // MARK: - Preview Mode (mock)

    private var previewModeSection: some View {
        VStack(alignment: .leading, spacing: LockInSpacing.m) {
            SectionHeader(
                title: "Preview Mode",
                trailing: isApproved ? "Fallback" : "Use For Now"
            )

            if isApproved {
                Text("Preview apps are for development and demos. Once you've chosen real apps above, you can ignore this section.")
                    .font(.system(size: 12, weight: .medium, design: .rounded))
                    .foregroundStyle(LockInColor.textTertiary)
                    .fixedSize(horizontal: false, vertical: true)
            }

            VStack(alignment: .leading, spacing: LockInSpacing.l) {
                quickPicksList
                appsList
                saveMockButton
            }
            .opacity(isApproved ? 0.78 : 1.0)
        }
    }

    private var quickPicksList: some View {
        VStack(alignment: .leading, spacing: 8) {
            Text("QUICK PICKS")
                .font(.system(size: 10, weight: .heavy, design: .rounded))
                .tracking(1.6)
                .foregroundStyle(LockInColor.textTertiary)
            VStack(spacing: 8) {
                ForEach(groups) { group in
                    Button {
                        applyGroup(group)
                    } label: {
                        GroupPresetRow(
                            group: group,
                            isActive: currentGroupMatch?.id == group.id
                        )
                    }
                    .buttonStyle(PressableScaleStyle())
                }
            }
        }
    }

    private var appsList: some View {
        VStack(alignment: .leading, spacing: 8) {
            Text("PREVIEW APPS")
                .font(.system(size: 10, weight: .heavy, design: .rounded))
                .tracking(1.6)
                .foregroundStyle(LockInColor.textTertiary)
            VStack(spacing: 8) {
                ForEach(apps) { app in
                    Button {
                        toggleMock(app.id)
                    } label: {
                        MockAppRow(app: app, isSelected: selectedMockIDs.contains(app.id))
                    }
                    .buttonStyle(PressableScaleStyle())
                }
            }
        }
    }

    private var saveMockButton: some View {
        PrimaryButton(
            title: hasUnsavedMockChanges ? "Save Preview Apps" : "Preview Apps Saved",
            systemImage: hasUnsavedMockChanges ? "tray.and.arrow.down.fill" : "checkmark.seal.fill",
            style: .secondary,
            isEnabled: hasUnsavedMockChanges
        ) {
            saveMockSelection()
        }
    }

    // MARK: - Footnote

    private var screenTimeNote: some View {
        Text("Real app monitoring connects after the Device Activity setup ships in a later update.")
            .font(.system(size: 12, weight: .medium, design: .rounded))
            .foregroundStyle(LockInColor.textTertiary)
            .multilineTextAlignment(.center)
            .frame(maxWidth: .infinity, alignment: .center)
            .padding(.top, LockInSpacing.s)
    }

    // MARK: - Actions

    private func presentPicker() {
        selectionBeforePicker = familyStore.selection
        isPickerPresented = true
    }

    private func requestScreenTime() async {
        isRequestingAuth = true
        _ = await screenTime.requestAuthorization()
        isRequestingAuth = false
        switch screenTime.authState {
        case .approved:       showStatus("Screen Time access enabled. Tap Choose Apps.")
        case .denied:         showStatus("Access denied. You can still use Preview Mode.")
        case .error(let msg): showStatus("Couldn't enable: \(msg)")
        case .notDetermined:  break
        }
    }

    private func toggleMock(_ id: String) {
        if selectedMockIDs.contains(id) {
            selectedMockIDs.remove(id)
        } else {
            selectedMockIDs.insert(id)
        }
    }

    private func applyGroup(_ group: LockInAppGroup) {
        if currentGroupMatch?.id == group.id {
            selectedMockIDs.removeAll()
        } else {
            selectedMockIDs = Set(group.appIDs)
        }
    }

    private func saveMockSelection() {
        let orderedIDs = apps.map(\.id).filter { selectedMockIDs.contains($0) }
        savedAppIDsRaw  = SelectedAppsStorage.encode(orderedIDs)
        savedAppGroupID = currentGroupMatch?.id ?? ""
        let count = orderedIDs.count
        let groupName = currentGroupMatch?.name
        let message: String
        switch count {
        case 0:  message = "Preview apps cleared."
        case 1:  message = groupName.map { "Saved. \($0) (1 app)." } ?? "Saved. 1 preview app."
        default: message = groupName.map { "Saved. \($0) (\(count) apps)." } ?? "Saved. \(count) preview apps."
        }
        showStatus(message)
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

// MARK: - Group preset row

private struct GroupPresetRow: View {
    let group: LockInAppGroup
    let isActive: Bool

    var body: some View {
        HStack(spacing: 12) {
            ZStack {
                RoundedRectangle(cornerRadius: 10, style: .continuous)
                    .fill(LockInColor.accent.opacity(isActive ? 0.22 : 0.12))
                    .frame(width: 36, height: 36)
                Image(systemName: group.systemImage)
                    .font(.system(size: 14, weight: .semibold))
                    .foregroundStyle(isActive ? LockInColor.accent : LockInColor.textSecondary)
            }

            VStack(alignment: .leading, spacing: 2) {
                Text(group.name)
                    .font(.system(size: 14.5, weight: .bold, design: .rounded))
                    .foregroundStyle(LockInColor.textPrimary)
                Text(group.appIDs.compactMap { MockApp.app(withID: $0)?.name }.joined(separator: ", "))
                    .font(.system(size: 12, weight: .medium, design: .rounded))
                    .foregroundStyle(LockInColor.textSecondary)
                    .lineLimit(1)
            }

            Spacer(minLength: 0)

            Text(isActive ? "ACTIVE" : "APPLY")
                .font(.system(size: 10, weight: .heavy, design: .rounded))
                .tracking(1.4)
                .foregroundStyle(isActive ? LockInColor.accent : LockInColor.textTertiary)
        }
        .padding(.vertical, 10)
        .padding(.horizontal, 12)
        .frame(maxWidth: .infinity, alignment: .leading)
        .background(
            RoundedRectangle(cornerRadius: LockInRadius.m, style: .continuous)
                .fill(LockInColor.surface)
        )
        .overlay(
            RoundedRectangle(cornerRadius: LockInRadius.m, style: .continuous)
                .strokeBorder(
                    isActive ? LockInColor.accent.opacity(0.45) : LockInColor.border,
                    lineWidth: isActive ? 1.2 : 1
                )
        )
    }
}

// MARK: - Mock app row

private struct MockAppRow: View {
    let app: MockApp
    let isSelected: Bool

    var body: some View {
        HStack(spacing: 14) {
            ZStack {
                RoundedRectangle(cornerRadius: 10, style: .continuous)
                    .fill(app.accent.opacity(isSelected ? 0.30 : 0.16))
                    .frame(width: 36, height: 36)
                Image(systemName: app.symbolName)
                    .font(.system(size: 15, weight: .bold))
                    .foregroundStyle(.white)
            }

            Text(app.name)
                .font(.system(size: 15, weight: .semibold, design: .rounded))
                .foregroundStyle(LockInColor.textPrimary)

            Spacer(minLength: 0)

            Image(systemName: isSelected ? "checkmark.circle.fill" : "circle")
                .font(.system(size: 18, weight: isSelected ? .bold : .regular))
                .foregroundStyle(isSelected ? LockInColor.accent : LockInColor.textTertiary)
        }
        .padding(.vertical, 10)
        .padding(.horizontal, 12)
        .frame(maxWidth: .infinity, alignment: .leading)
        .background(
            RoundedRectangle(cornerRadius: LockInRadius.m, style: .continuous)
                .fill(isSelected ? LockInColor.surfaceElevated : LockInColor.surface)
        )
        .overlay(
            RoundedRectangle(cornerRadius: LockInRadius.m, style: .continuous)
                .strokeBorder(
                    isSelected ? LockInColor.accent.opacity(0.45) : LockInColor.border,
                    lineWidth: isSelected ? 1.2 : 1
                )
        )
    }
}

#Preview {
    NavigationStack {
        AppSelectionView()
    }
    .preferredColorScheme(.dark)
}
