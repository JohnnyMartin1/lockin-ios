//
//  AppSelectionView.swift
//  LockIn
//

import SwiftUI

struct AppSelectionView: View {
    @Environment(\.dismiss) private var dismiss

    @AppStorage(SelectedAppsKeys.ids) private var savedAppIDsRaw: String = ""
    @AppStorage(LockInSetupKeys.appGroupID) private var savedAppGroupID: String = ""

    @State private var selectedIDs: Set<String>
    @State private var statusMessage: String?

    private let apps = MockApp.bundled
    private let groups = LockInAppGroup.presets

    init() {
        let raw = UserDefaults.standard.string(forKey: SelectedAppsKeys.ids) ?? ""
        _selectedIDs = State(initialValue: Set(SelectedAppsStorage.decode(raw)))
    }

    private var savedIDs: Set<String> { Set(SelectedAppsStorage.decode(savedAppIDsRaw)) }
    private var hasUnsavedChanges: Bool {
        savedIDs != selectedIDs
            || savedAppGroupID != (currentGroupMatch?.id ?? "")
    }

    /// The preset group that matches the current selection exactly, if any.
    private var currentGroupMatch: LockInAppGroup? {
        LockInAppGroup.match(forSelectedAppIDs: Array(selectedIDs))
    }

    private var selectedCountLabel: String {
        let n = selectedIDs.count
        return n == 1 ? "1 selected" : "\(n) selected"
    }

    var body: some View {
        ZStack {
            LockInBackground()

            ScrollView {
                VStack(alignment: .leading, spacing: LockInSpacing.xl) {
                    topBar
                    header
                    groupsSection
                    appsSection
                    saveButton
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
    }

    // MARK: - Top bar / header

    private var topBar: some View {
        HStack(spacing: 12) {
            LockInBackPill(action: { dismiss() }, label: "Home")
            Spacer()
            PillBadge(text: selectedCountLabel, style: .neutral, systemImage: "checkmark.seal.fill")
        }
    }

    private var header: some View {
        VStack(alignment: .leading, spacing: 8) {
            LockInType.screenTitle("Apps to Watch")
            LockInType.screenSubtitle("Pick the apps that usually steal your time.")
        }
    }

    // MARK: - Groups

    private var groupsSection: some View {
        VStack(alignment: .leading, spacing: LockInSpacing.m) {
            SectionHeader(title: "Quick Picks")
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

    // MARK: - Apps list

    private var appsSection: some View {
        VStack(alignment: .leading, spacing: LockInSpacing.m) {
            SectionHeader(title: "Individual Apps")
            VStack(spacing: 8) {
                ForEach(apps) { app in
                    Button {
                        toggle(app.id)
                    } label: {
                        MockAppRow(app: app, isSelected: selectedIDs.contains(app.id))
                    }
                    .buttonStyle(PressableScaleStyle())
                }
            }
        }
    }

    // MARK: - Save

    private var saveButton: some View {
        PrimaryButton(
            title: hasUnsavedChanges ? "Save Apps" : "Apps saved",
            systemImage: hasUnsavedChanges ? "tray.and.arrow.down.fill" : "checkmark.seal.fill",
            style: .primary,
            isEnabled: hasUnsavedChanges
        ) {
            saveSelection()
        }
    }

    // MARK: - Footnote

    private var screenTimeNote: some View {
        Text("Automatic app monitoring will connect to Apple Screen Time permissions later.")
            .font(.system(size: 12, weight: .medium, design: .rounded))
            .foregroundStyle(LockInColor.textTertiary)
            .multilineTextAlignment(.center)
            .frame(maxWidth: .infinity, alignment: .center)
            .padding(.top, LockInSpacing.s)
    }

    // MARK: - Actions

    private func toggle(_ id: String) {
        if selectedIDs.contains(id) {
            selectedIDs.remove(id)
        } else {
            selectedIDs.insert(id)
        }
    }

    private func applyGroup(_ group: LockInAppGroup) {
        if currentGroupMatch?.id == group.id {
            // Tapping the active group clears all.
            selectedIDs.removeAll()
        } else {
            selectedIDs = Set(group.appIDs)
        }
    }

    private func saveSelection() {
        let orderedIDs = apps.map(\.id).filter { selectedIDs.contains($0) }
        savedAppIDsRaw = SelectedAppsStorage.encode(orderedIDs)
        savedAppGroupID = currentGroupMatch?.id ?? ""
        let count = orderedIDs.count
        let groupName = currentGroupMatch?.name
        let message: String
        switch count {
        case 0: message = "Apps saved. No apps selected."
        case 1: message = groupName.map { "Apps saved. \($0) (1 app)." } ?? "Apps saved. 1 app locked in."
        default: message = groupName.map { "Apps saved. \($0) (\(count) apps)." } ?? "Apps saved. \(count) apps locked in."
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
                    .frame(width: 38, height: 38)
                Image(systemName: group.systemImage)
                    .font(.system(size: 15, weight: .semibold))
                    .foregroundStyle(isActive ? LockInColor.accent : LockInColor.textSecondary)
            }

            VStack(alignment: .leading, spacing: 2) {
                Text(group.name)
                    .font(.system(size: 15, weight: .bold, design: .rounded))
                    .foregroundStyle(LockInColor.textPrimary)
                Text(group.appIDs.compactMap { MockApp.app(withID: $0)?.name }.joined(separator: ", "))
                    .font(.system(size: 12.5, weight: .medium, design: .rounded))
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

// MARK: - App row

private struct MockAppRow: View {
    let app: MockApp
    let isSelected: Bool

    var body: some View {
        HStack(spacing: 14) {
            ZStack {
                RoundedRectangle(cornerRadius: 10, style: .continuous)
                    .fill(app.accent.opacity(isSelected ? 0.30 : 0.16))
                    .frame(width: 38, height: 38)
                Image(systemName: app.symbolName)
                    .font(.system(size: 16, weight: .bold))
                    .foregroundStyle(.white)
            }

            Text(app.name)
                .font(.system(size: 15.5, weight: .semibold, design: .rounded))
                .foregroundStyle(LockInColor.textPrimary)

            Spacer(minLength: 0)

            Image(systemName: isSelected ? "checkmark.circle.fill" : "circle")
                .font(.system(size: 19, weight: isSelected ? .bold : .regular))
                .foregroundStyle(isSelected ? LockInColor.accent : LockInColor.textTertiary)
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
