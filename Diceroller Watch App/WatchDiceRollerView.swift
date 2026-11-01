//
//  WatchDiceRollerView.swift
//  Diceroller Watch App
//
//  Created by James McDonald on 08/03/2025.
//

import SwiftUI

/// Screens pushed from the watch's root list, other than rolling a specific configuration.
enum WatchRoute: Hashable {
    case customRoll
}

/// The custom roll's wheel positions. The id stays fixed so pushing the roll reuses the same identity.
struct CustomRollSettings: Hashable {
    let id = UUID()
    var numberOfDice = 1
    var dieType = DieType.defaultDie
    var modifier = 0

    var config: RollConfig {
        RollConfig(id: id, name: "", expression: .simple(count: numberOfDice, sides: dieType.rawValue, modifier: modifier))
    }
}

/// The watch's first screen: saved rolls synced from the phone, plus a custom roll.
/// Tapping a saved roll rolls it straight away.
struct WatchDiceRollerView: View {
    @Environment(RollStore.self) private var store

    /// Kept here so the custom roll remembers its last settings while the app is running.
    @State private var customRoll = CustomRollSettings()

    var body: some View {
        NavigationStack {
            List {
                NavigationLink(value: WatchRoute.customRoll) {
                    Label("Custom Roll", systemImage: "slider.horizontal.3")
                }

                Section("Saved") {
                    if store.configs.isEmpty {
                        Text("Save rolls on your iPhone to see them here.")
                            .font(.footnote)
                            .foregroundStyle(.secondary)
                    }

                    ForEach(store.configs) { config in
                        NavigationLink(value: config) {
                            VStack(alignment: .leading) {
                                Text(config.name)
                                Text(config.notation)
                                    .font(.footnote)
                                    .foregroundStyle(.secondary)
                            }
                        }
                    }
                }
            }
            .navigationTitle("Diceroller")
            .navigationDestination(for: RollConfig.self) { config in
                WatchRollView(config: config)
            }
            .navigationDestination(for: WatchRoute.self) { route in
                switch route {
                case .customRoll:
                    CustomRollView(config: $customRoll)
                }
            }
        }
    }
}

/// Picks dice, die type, and modifier with three wheels that follow the Digital Crown.
struct CustomRollView: View {
    @Binding var config: CustomRollSettings

    var body: some View {
        VStack {
            HStack(spacing: 2) {
                Picker("Dice", selection: $config.numberOfDice) {
                    ForEach(RollConfig.numberOfDiceRange, id: \.self) { count in
                        Text("\(count)").tag(count)
                    }
                }
                Picker("Die", selection: $config.dieType) {
                    ForEach(DieType.allCases, id: \.self) { die in
                        Text(die.description).tag(die)
                    }
                }
                Picker("Mod", selection: $config.modifier) {
                    ForEach(RollConfig.modifierRange, id: \.self) { modifier in
                        Text(modifier > 0 ? "+\(modifier)" : "\(modifier)").tag(modifier)
                    }
                }
            }
            .pickerStyle(.wheel)

            NavigationLink(value: config.config) {
                Label("Roll", systemImage: "dice")
            }
            .buttonStyle(.borderedProminent)
        }
        .navigationTitle(config.config.notation)
    }
}

/// Rolls a configuration as soon as it appears, with a button to roll again.
struct WatchRollView: View {
    let config: RollConfig

    @State private var result: RollResult?
    @State private var rollCount = 0

    private var totalColor: Color {
        guard let result else { return .primary }
        if result.isNaturalOne { return .red }
        if result.isNaturalMax { return .green }
        return .primary
    }

    var body: some View {
        VStack(spacing: 4) {
            Text(result.map { "\($0.total)" } ?? " ")
                .font(.system(size: 56, weight: .bold, design: .rounded))
                .foregroundStyle(totalColor)
                .contentTransition(.numericText())
            Text(result?.breakdown ?? " ")
                .font(.footnote)
                .foregroundStyle(.secondary)
                .multilineTextAlignment(.center)
                .lineLimit(2)
                .minimumScaleFactor(0.7)
            Spacer(minLength: 0)
            Button("Roll Again", systemImage: "arrow.clockwise", action: roll)
        }
        .navigationTitle(config.name.isEmpty ? config.notation : config.name)
        .sensoryFeedback(.success, trigger: rollCount)
        .onAppear {
            if result == nil {
                roll()
            }
        }
    }

    private func roll() {
        withAnimation(.snappy) {
            result = config.roll()
        }
        rollCount += 1
    }
}

#Preview {
    WatchDiceRollerView()
        .environment(RollStore.preview())
}

#Preview("Custom Roll") {
    @Previewable @State var config = CustomRollSettings(numberOfDice: 2, dieType: .d6, modifier: 3)
    NavigationStack {
        CustomRollView(config: $config)
    }
}

#Preview("Roll Result") {
    NavigationStack {
        WatchRollView(config: RollConfig(name: "Blessed Attack", expression: (try? DiceExpressionParser.parse("1d20 + 1d4 + 5 (adv)")) ?? .simple(count: 1, sides: 20, modifier: 5)))
    }
}
