//
//  AppSelectionView.swift
//  LockIn
//

import SwiftUI

struct AppSelectionView: View {
    @Environment(\.dismiss) private var dismiss

    @AppStorage(SelectedAppsKeys.ids) private var savedAppIDsRaw: String = ""

    @State private var selectedIDs: Set<String>
    @State private var statusMessage: String?

    private let apps = MockApp.bundled

    init() {
        let raw = UserDefaults.standard.string(forKey: SelectedAppsKeys.ids) ?? ""
        _selectedIDs = State(initialValue: Set(SelectedAppsStorage.decode(raw)))
    }

    private var savedIDs: Set<String> { Set(SelectedAppsStorage.decode(savedAppIDsRaw)) }
    private var hasUnsavedChanges: Bool { savedIDs != selectedIDs }

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
                    appList
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

    // MARK: - Top bar

    private var topBar: some View {
        HStack(spacing: 12) {
            LockInBackPill(action: { dismiss() }, label: "Home")
            Spacer()
            PillBadge(text: selectedCountLabel, style: .neutral, systemImage: "checkmark.seal.fill")
        }
    }

    // MARK: - Header

    private var header: some View {
        VStack(alignment: .leading, spacing: 8) {
            LockInType.screenTitle("Apps to Watch")
            LockInType.screenSubtitle("Pick the apps that usually steal your time.")
        }
    }

    // MARK: - App list

    private var appList: some View {
        VStack(spacing: 10) {
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

    // MARK: - Screen Time note

    private var screenTimeNote: some View {
        Text("Real app monitoring will use Apple Screen Time permissions.")
            .font(.system(size: 12, weight: .medium, design: .rounded))
            .foregroundStyle(LockInColor.textTertiary)
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

    private func saveSelection() {
        let orderedIDs = apps.map(\.id).filter { selectedIDs.contains($0) }
        savedAppIDsRaw = SelectedAppsStorage.encode(orderedIDs)
        let count = orderedIDs.count
        let message: String
        switch count {
        case 0: message = "Apps saved. No apps selected."
        case 1: message = "Apps saved. 1 app locked in."
        default: message = "Apps saved. \(count) apps locked in."
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

// MARK: - App row

private struct MockAppRow: View {
    let app: MockApp
    let isSelected: Bool

    var body: some View {
        HStack(spacing: 14) {
            ZStack {
                RoundedRectangle(cornerRadius: 10, style: .continuous)
                    .fill(app.accent.opacity(isSelected ? 0.30 : 0.16))
                    .frame(width: 40, height: 40)
                Image(systemName: app.symbolName)
                    .font(.system(size: 17, weight: .bold))
                    .foregroundStyle(.white)
            }

            Text(app.name)
                .font(.system(size: 16, weight: .semibold, design: .rounded))
                .foregroundStyle(LockInColor.textPrimary)

            Spacer(minLength: 0)

            Image(systemName: isSelected ? "checkmark.circle.fill" : "circle")
                .font(.system(size: 20, weight: isSelected ? .bold : .regular))
                .foregroundStyle(isSelected ? LockInColor.accent : LockInColor.textTertiary)
        }
        .padding(.vertical, 12)
        .padding(.horizontal, 14)
        .frame(maxWidth: .infinity, alignment: .leading)
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
        AppSelectionView()
    }
    .preferredColorScheme(.dark)
}
