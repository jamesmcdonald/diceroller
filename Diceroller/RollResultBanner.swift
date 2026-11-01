//
//  RollResultBanner.swift
//  Diceroller
//

import SwiftUI

/// The most recent roll, with the config that produced it so it can be rolled again.
struct LastRoll {
    let title: String
    let config: RollConfig
    let result: RollResult
}

/// Shows the most recent roll pinned to the bottom of the screen, so it's visible
/// whichever roll was tapped.
struct RollResultBanner: View {
    let lastRoll: LastRoll
    let rollAgain: () -> Void

    private var result: RollResult { lastRoll.result }

    private var totalText: String {
        if let nat = result.natural, result.dieType == .d20, result.isNaturalOne || result.isNaturalMax {
            return "Nat \(nat) (\(result.total))"
        }
        return "\(result.total)"
    }

    private var totalColor: Color {
        if result.isNaturalOne { return .red }
        if result.isNaturalMax { return .green }
        return .primary
    }

    var body: some View {
        HStack(alignment: .center) {
            VStack(alignment: .leading, spacing: 2) {
                Text(lastRoll.title)
                    .font(.headline)
                Text(totalText)
                    .font(.largeTitle)
                    .fontWeight(.bold)
                    .foregroundStyle(totalColor)
                    .contentTransition(.numericText())
                Text(result.breakdown)
                    .font(.footnote)
                    .foregroundStyle(.secondary)
            }
            Spacer()
            Button("Roll Again", systemImage: "arrow.clockwise", action: rollAgain)
                .labelStyle(.iconOnly)
                .font(.title2)
                .buttonStyle(.bordered)
        }
        .padding()
        .background(.regularMaterial, in: .rect(cornerRadius: 16))
        .padding(.horizontal)
        .accessibilityElement(children: .combine)
        .accessibilityAction(named: "Roll Again", rollAgain)
    }
}
