// SanePromisePage.swift
// SaneProcess Template — Required in ALL SaneApps onboarding flows
//
// Copy this file into your app's onboarding directory and add it as the
// final page before the "Get Started" / completion button.
//
// The three pillars (Power, Love, Sound Mind) come directly from the
// Sane North Star (2 Timothy 1:7). This is the brand promise — not optional.
//
// Usage:
//   SanePromisePage()          // standard
//   SanePromisePage(compact: true)  // for smaller windows (< 600pt wide)

import SwiftUI

struct SanePromisePage: View {
    var compact: Bool = false

    var body: some View {
        VStack(spacing: compact ? 16 : 24) {
            Text("Our Sane Philosophy")
                .font(.system(size: compact ? 24 : 32, weight: .bold))

            VStack(spacing: 8) {
                Text("\"For God has not given us a spirit of fear,")
                    .font(.system(size: compact ? 14 : 17))
                    .italic()
                Text("but of power and of love and of a sound mind.\"")
                    .font(.system(size: compact ? 14 : 17))
                    .italic()
                Text("— 2 Timothy 1:7")
                    .font(.system(size: compact ? 13 : 15, weight: .medium))
                    .foregroundStyle(.primary)
                    .padding(.top, 4)
            }

            if compact {
                VStack(spacing: 12) {
                    pillarCards
                }
            } else {
                HStack(spacing: 20) {
                    pillarCards
                }
                .padding(.horizontal, 16)
                .padding(.top, 12)
            }
        }
        .padding(compact ? 20 : 32)
    }

    @ViewBuilder
    private var pillarCards: some View {
        SanePillarCard(
            icon: "bolt.fill",
            color: .yellow,
            title: "Power",
            description: "Your data stays on your device. No cloud, no tracking."
        )

        SanePillarCard(
            icon: "heart.fill",
            color: .pink,
            title: "Love",
            description: "Built to serve you. No dark patterns or manipulation."
        )

        SanePillarCard(
            icon: "brain.head.profile",
            color: .purple,
            title: "Sound Mind",
            description: "Calm, focused design. No clutter or anxiety."
        )
    }
}

struct SanePillarCard: View {
    let icon: String
    let color: Color
    let title: String
    let description: String

    var body: some View {
        VStack(spacing: 12) {
            Image(systemName: icon)
                .font(.system(size: 32))
                .foregroundStyle(color)

            Text(title)
                .font(.system(size: 18, weight: .semibold))

            Text(description)
                .font(.system(size: 14))
                .foregroundStyle(.primary)
                .multilineTextAlignment(.center)
                .lineLimit(3)
                .fixedSize(horizontal: false, vertical: true)
        }
        .frame(maxWidth: .infinity)
        .padding(.vertical, 18)
        .padding(.horizontal, 14)
        .background(Color.primary.opacity(0.08))
        .cornerRadius(12)
    }
}
