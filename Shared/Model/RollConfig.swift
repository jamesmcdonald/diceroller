//
//  RollConfig.swift
//  Diceroller
//
//  Created by James McDonald on 08/03/2025.
//

import Foundation

/// A configuration for a saved roll, defining the number and type of dice, and any modifier.
struct RollConfig : Codable, Equatable, Hashable, Identifiable {
    /// The supported number of dice in a single roll, shared by the phone and watch UIs.
    static let numberOfDiceRange = 1...50

    /// The supported modifier values, shared by the phone and watch UIs.
    static let modifierRange = -20...20

    /// Stable identity, so a saved roll can be renamed or reordered without becoming a different roll.
    let id: UUID

    /// The name of this configuration, for example "Attack" or "Fireball"
    var name: String;

    /// The number of dice to roll.
    var numberOfDice: Int;

    /// The type of die.
    var dieType: DieType;

    /// Any modifier, such as a +3 to an attack roll.
    var modifier: Int;

    init(id: UUID = UUID(), name: String, numberOfDice: Int, dieType: DieType, modifier: Int) {
        self.id = id
        self.name = name
        self.numberOfDice = numberOfDice
        self.dieType = dieType
        self.modifier = modifier
    }

    /// Decodes a configuration, assigning a new id to data saved before ids existed.
    init(from decoder: any Decoder) throws {
        let container = try decoder.container(keyedBy: CodingKeys.self)
        id = try container.decodeIfPresent(UUID.self, forKey: .id) ?? UUID()
        name = try container.decode(String.self, forKey: .name)
        numberOfDice = try container.decode(Int.self, forKey: .numberOfDice)
        dieType = try container.decode(DieType.self, forKey: .dieType)
        modifier = try container.decode(Int.self, forKey: .modifier)
    }

    /// Dice notation for this configuration, for example "2D6 + 3".
    var notation: String {
        let dice = "\(numberOfDice)\(dieType.description)"
        if modifier == 0 {
            return dice
        }
        return modifier > 0 ? "\(dice) + \(modifier)" : "\(dice) - \(abs(modifier))"
    }

    /// Rolls the dice using the system random number generator.
    func roll() -> RollResult {
        var generator = SystemRandomNumberGenerator()
        return roll(using: &generator)
    }

    /// Rolls the dice using the given generator, so tests can supply a seeded one.
    func roll<G: RandomNumberGenerator>(using generator: inout G) -> RollResult {
        let rolls = (0..<numberOfDice).map { _ in
            Int.random(in: 1...dieType.rawValue, using: &generator)
        }
        return RollResult(dieType: dieType, rolls: rolls, modifier: modifier)
    }
}
