//
//  RollConfigControls.swift
//  Diceroller
//

import SwiftUI

/// Rows for choosing the number of dice, die type, and modifier.
/// Used by both the quick roll section and the save/edit sheet.
struct RollConfigControls: View {
    @Binding var config: RollConfig

    var body: some View {
        Stepper("Dice: \(config.numberOfDice)", value: $config.numberOfDice, in: RollConfig.numberOfDiceRange)

        Picker("Die", selection: $config.dieType) {
            ForEach(DieType.allCases, id: \.self) { die in
                Text(die.description).tag(die)
            }
        }
        .pickerStyle(.segmented)

        Stepper("Modifier: \(config.modifier > 0 ? "+" : "")\(config.modifier)", value: $config.modifier, in: RollConfig.modifierRange)
    }
}
