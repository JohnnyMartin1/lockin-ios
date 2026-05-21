//
//  Theme.swift
//  LockIn
//
//  Visual tokens for the LockIn UI.
//

import SwiftUI

// MARK: - Color palette

enum LockInColor {
    /// Near-black page background.
    static let background = Color(red: 0.040, green: 0.042, blue: 0.052)
    /// Subtle elevated surface (cards, rows).
    static let surface = Color.white.opacity(0.05)
    /// Slightly stronger surface for emphasized cards.
    static let surfaceElevated = Color.white.opacity(0.08)
    /// Hairline border on surfaces.
    static let border = Color.white.opacity(0.08)
    /// Stronger border for selected / focused states.
    static let borderStrong = Color.white.opacity(0.18)

    static let textPrimary = Color.white
    static let textSecondary = Color.white.opacity(0.65)
    static let textTertiary = Color.white.opacity(0.45)
    static let textMuted = Color.white.opacity(0.30)

    /// Single global brand accent — a muted, mature warm red.
    static let accent = Color(red: 0.770, green: 0.290, blue: 0.240)
    static let accentSoft = Color(red: 0.770, green: 0.290, blue: 0.240).opacity(0.18)
    static let accentTint = Color(red: 0.770, green: 0.290, blue: 0.240).opacity(0.10)

    static let success = Color(red: 0.45, green: 0.65, blue: 0.50)
    static let warning = Color(red: 0.90, green: 0.65, blue: 0.30)
}

// MARK: - Spacing & radius

enum LockInSpacing {
    static let xs: CGFloat = 4
    static let s: CGFloat = 8
    static let m: CGFloat = 12
    static let l: CGFloat = 16
    static let xl: CGFloat = 24
    static let xxl: CGFloat = 32
    static let xxxl: CGFloat = 40
}

enum LockInRadius {
    static let s: CGFloat = 10
    static let m: CGFloat = 14
    static let l: CGFloat = 18
    static let xl: CGFloat = 22
}

// MARK: - Type

enum LockInType {
    static func wordmark(_ text: String, size: CGFloat = 16) -> some View {
        Text(text.uppercased())
            .font(.system(size: size, weight: .heavy, design: .rounded))
            .tracking(size * 0.30)
            .foregroundStyle(LockInColor.textPrimary)
    }

    static func screenTitle(_ text: String) -> some View {
        Text(text)
            .font(.system(size: 26, weight: .heavy, design: .rounded))
            .foregroundStyle(LockInColor.textPrimary)
            .fixedSize(horizontal: false, vertical: true)
    }

    static func screenSubtitle(_ text: String) -> some View {
        Text(text)
            .font(.system(size: 14.5, weight: .medium, design: .rounded))
            .foregroundStyle(LockInColor.textSecondary)
            .fixedSize(horizontal: false, vertical: true)
    }
}
