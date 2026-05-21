//
//  ScreenTimeManager.swift
//  LockIn
//
//  Phase A: Real Screen Time authorization for the in-app app picker.
//  Only handles authorization. DeviceActivity monitoring is intentionally
//  not added here yet — that lands in Phase B (Monitor Extension).
//

import Combine
import FamilyControls
import Foundation

@MainActor
final class ScreenTimeManager: ObservableObject {

    /// Friendly authorization state for SwiftUI binding.
    enum AuthState: Equatable {
        case notDetermined
        case approved
        case denied
        case error(String)

        var isApproved: Bool {
            if case .approved = self { return true }
            return false
        }

        /// Compact identifier for debug logs and Developer Debug UI.
        var displayDescription: String {
            switch self {
            case .notDetermined: return "notDetermined"
            case .approved:      return "approved"
            case .denied:        return "denied"
            case .error(let s):  return "error(\(s))"
            }
        }
    }

    static let shared = ScreenTimeManager()

    @Published private(set) var authState: AuthState = .notDetermined

    private init() {
        refreshAuthorizationStatus()
    }

    /// Reads the current authorization status from `AuthorizationCenter`.
    /// Safe to call repeatedly (e.g. from `.onAppear`) so the UI stays in sync
    /// after the user toggles Screen Time in iOS Settings.
    func refreshAuthorizationStatus() {
        switch AuthorizationCenter.shared.authorizationStatus {
        case .notDetermined: authState = .notDetermined
        case .approved:      authState = .approved
        case .denied:        authState = .denied
        @unknown default:    authState = .notDetermined
        }
        print("[LockIn] ScreenTime authorization status: \(authState.displayDescription)")
    }

    /// Requests Screen Time access for the current user. Returns the resulting
    /// state. Never throws — errors are surfaced as `.error`.
    @discardableResult
    func requestAuthorization() async -> AuthState {
        do {
            try await AuthorizationCenter.shared.requestAuthorization(for: .individual)
            refreshAuthorizationStatus()
            print("[LockIn] ScreenTime requestAuthorization completed — \(authState.displayDescription)")
        } catch {
            let message = (error as NSError).localizedDescription
            print("[LockIn] ScreenTime requestAuthorization failed: \(error)")
            // Re-read in case the OS already flipped the status before throwing.
            refreshAuthorizationStatus()
            if !authState.isApproved && authState != .denied {
                authState = .error(message)
            }
        }
        return authState
    }
}
