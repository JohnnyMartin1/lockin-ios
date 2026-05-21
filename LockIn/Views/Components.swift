//
//  Components.swift
//  LockIn
//
//  Small reusable view components for the LockIn UI.
//

import SwiftUI

// MARK: - Background

struct LockInBackground: View {
    var body: some View {
        ZStack {
            LockInColor.background
            // One subtle top vignette — no dual radial gradients.
            RadialGradient(
                colors: [Color.white.opacity(0.05), Color.clear],
                center: .top,
                startRadius: 0,
                endRadius: 340
            )
        }
        .ignoresSafeArea()
    }
}

// MARK: - Card

struct LockInCard<Content: View>: View {
    enum Emphasis {
        case standard
        case elevated
        case accent
    }

    var emphasis: Emphasis = .standard
    var padding: CGFloat = LockInSpacing.l
    @ViewBuilder var content: () -> Content

    var body: some View {
        content()
            .padding(padding)
            .frame(maxWidth: .infinity, alignment: .leading)
            .background(
                RoundedRectangle(cornerRadius: LockInRadius.l, style: .continuous)
                    .fill(fillColor)
            )
            .overlay(
                RoundedRectangle(cornerRadius: LockInRadius.l, style: .continuous)
                    .strokeBorder(borderColor, lineWidth: 1)
            )
    }

    private var fillColor: Color {
        switch emphasis {
        case .standard: return LockInColor.surface
        case .elevated: return LockInColor.surfaceElevated
        case .accent:   return LockInColor.accentTint
        }
    }

    private var borderColor: Color {
        switch emphasis {
        case .standard, .elevated: return LockInColor.border
        case .accent:              return LockInColor.accent.opacity(0.45)
        }
    }
}

// MARK: - Pill badge

struct PillBadge: View {
    enum Style {
        case neutral
        case accent
        case premium
        case custom(Color)
    }

    let text: String
    var style: Style = .neutral
    var systemImage: String?

    var body: some View {
        HStack(spacing: 5) {
            if let systemImage {
                Image(systemName: systemImage)
                    .font(.system(size: 9, weight: .bold))
            }
            Text(text.uppercased())
                .font(.system(size: 10, weight: .heavy, design: .rounded))
                .tracking(1.1)
        }
        .foregroundStyle(foregroundColor)
        .padding(.vertical, 4)
        .padding(.horizontal, 8)
        .background(Capsule().fill(backgroundColor))
        .overlay(Capsule().strokeBorder(borderColor, lineWidth: 0.5))
    }

    private var foregroundColor: Color {
        switch style {
        case .neutral: return LockInColor.textSecondary
        case .accent:  return LockInColor.accent
        case .premium: return Color(red: 0.95, green: 0.78, blue: 0.40)
        case .custom(let c): return c
        }
    }

    private var backgroundColor: Color {
        switch style {
        case .neutral: return Color.white.opacity(0.06)
        case .accent:  return LockInColor.accent.opacity(0.16)
        case .premium: return Color(red: 0.95, green: 0.78, blue: 0.40).opacity(0.14)
        case .custom(let c): return c.opacity(0.16)
        }
    }

    private var borderColor: Color {
        switch style {
        case .neutral: return Color.white.opacity(0.10)
        case .accent:  return LockInColor.accent.opacity(0.40)
        case .premium: return Color(red: 0.95, green: 0.78, blue: 0.40).opacity(0.40)
        case .custom(let c): return c.opacity(0.40)
        }
    }
}

// MARK: - Primary button

struct PrimaryButton: View {
    enum Style {
        case primary    // accent fill
        case secondary  // outlined
        case ghost      // borderless
    }

    let title: String
    var systemImage: String?
    var style: Style = .primary
    var isEnabled: Bool = true
    let action: () -> Void

    var body: some View {
        Button(action: action) {
            HStack(spacing: 10) {
                if let systemImage {
                    Image(systemName: systemImage)
                        .font(.system(size: 15, weight: .bold))
                }
                Text(title)
                    .font(.system(size: 16, weight: .bold, design: .rounded))
            }
            .foregroundStyle(foregroundColor)
            .frame(maxWidth: .infinity)
            .padding(.vertical, 15)
            .background(backgroundView)
            .overlay(
                RoundedRectangle(cornerRadius: LockInRadius.m, style: .continuous)
                    .strokeBorder(borderColor, lineWidth: borderWidth)
            )
            .clipShape(RoundedRectangle(cornerRadius: LockInRadius.m, style: .continuous))
        }
        .buttonStyle(PressableScaleStyle())
        .disabled(!isEnabled)
        .opacity(isEnabled ? 1 : 0.55)
    }

    @ViewBuilder
    private var backgroundView: some View {
        switch style {
        case .primary:
            LockInColor.accent
        case .secondary:
            LockInColor.surface
        case .ghost:
            Color.clear
        }
    }

    private var foregroundColor: Color {
        switch style {
        case .primary:   return .white
        case .secondary: return LockInColor.textPrimary
        case .ghost:     return LockInColor.textSecondary
        }
    }

    private var borderColor: Color {
        switch style {
        case .primary:   return Color.white.opacity(0.12)
        case .secondary: return LockInColor.border
        case .ghost:     return Color.clear
        }
    }

    private var borderWidth: CGFloat {
        switch style {
        case .ghost: return 0
        default:     return 1
        }
    }
}

// MARK: - Section header

struct SectionHeader: View {
    let title: String
    var trailing: String?

    var body: some View {
        HStack {
            Text(title.uppercased())
                .font(.system(size: 11, weight: .heavy, design: .rounded))
                .tracking(2)
                .foregroundStyle(LockInColor.textTertiary)

            if let trailing {
                Spacer()
                Text(trailing.uppercased())
                    .font(.system(size: 11, weight: .heavy, design: .rounded))
                    .tracking(2)
                    .foregroundStyle(LockInColor.textTertiary)
            }
        }
    }
}

// MARK: - Setup summary row

struct SetupSummaryRow: View {
    let label: String
    let value: String
    var systemImage: String?
    var accent: Color = LockInColor.textPrimary
    var trailingIcon: String? = "chevron.right"

    var body: some View {
        HStack(spacing: 14) {
            if let systemImage {
                ZStack {
                    RoundedRectangle(cornerRadius: 10, style: .continuous)
                        .fill(accent.opacity(0.16))
                        .frame(width: 36, height: 36)
                    Image(systemName: systemImage)
                        .font(.system(size: 15, weight: .semibold))
                        .foregroundStyle(accent)
                }
            }

            VStack(alignment: .leading, spacing: 2) {
                Text(label.uppercased())
                    .font(.system(size: 10, weight: .heavy, design: .rounded))
                    .tracking(1.4)
                    .foregroundStyle(LockInColor.textTertiary)
                Text(value)
                    .font(.system(size: 15, weight: .semibold, design: .rounded))
                    .foregroundStyle(LockInColor.textPrimary)
                    .lineLimit(1)
            }

            Spacer(minLength: 0)

            if let trailingIcon {
                Image(systemName: trailingIcon)
                    .font(.system(size: 12, weight: .semibold))
                    .foregroundStyle(LockInColor.textTertiary)
            }
        }
    }
}

// MARK: - Status banner

struct LockInStatusBanner: View {
    let message: String
    var systemImage: String = "checkmark.seal.fill"
    var tint: Color = LockInColor.accent

    var body: some View {
        HStack(alignment: .top, spacing: 12) {
            Image(systemName: systemImage)
                .font(.system(size: 13, weight: .bold))
                .foregroundStyle(tint)
            Text(message)
                .font(.system(size: 13.5, weight: .medium, design: .rounded))
                .foregroundStyle(LockInColor.textPrimary.opacity(0.9))
                .fixedSize(horizontal: false, vertical: true)
            Spacer(minLength: 0)
        }
        .padding(13)
        .frame(maxWidth: .infinity, alignment: .leading)
        .background(
            RoundedRectangle(cornerRadius: LockInRadius.m, style: .continuous)
                .fill(LockInColor.surface)
        )
        .overlay(
            RoundedRectangle(cornerRadius: LockInRadius.m, style: .continuous)
                .strokeBorder(tint.opacity(0.32), lineWidth: 1)
        )
        .transition(.opacity)
    }
}

// MARK: - Back pill (used as a top-bar back button)

struct LockInBackPill: View {
    let action: () -> Void
    var label: String = "Back"

    var body: some View {
        Button(action: action) {
            HStack(spacing: 6) {
                Image(systemName: "chevron.left")
                    .font(.system(size: 13, weight: .bold))
                Text(label)
                    .font(.system(size: 14, weight: .semibold, design: .rounded))
            }
            .foregroundStyle(LockInColor.textSecondary)
            .padding(.vertical, 8)
            .padding(.horizontal, 12)
            .background(Capsule().fill(LockInColor.surface))
            .overlay(Capsule().strokeBorder(LockInColor.border, lineWidth: 1))
        }
        .buttonStyle(.plain)
    }
}

// MARK: - Press feedback

struct PressableScaleStyle: ButtonStyle {
    func makeBody(configuration: Configuration) -> some View {
        configuration.label
            .scaleEffect(configuration.isPressed ? 0.97 : 1.0)
            .opacity(configuration.isPressed ? 0.9 : 1.0)
            .animation(.easeOut(duration: 0.12), value: configuration.isPressed)
    }
}
