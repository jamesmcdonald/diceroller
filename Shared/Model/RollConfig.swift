//
//  RollConfig.swift
//  Diceroller
//
//  Created by James McDonald on 08/03/2025.
//

/// A configuration for a saved roll, defining the number and type of dice, and any modifier.
struct RollConfig : Codable, Equatable {
    /// The supported number of dice in a single roll, shared by the phone and watch UIs.
    static let numberOfDiceRange = 1...50

    /// The supported modifier values, shared by the phone and watch UIs.
    static let modifierRange = -20...20

    /// The name of this configuration, for example "Attack" or "Fireball"
    var name: String;

    /// The number of dice to roll.
    var numberOfDice: Int;

    /// The type of die.
    var dieType: DieType;

    /// Any modifier, such as a +3 to an attack roll.
    var modifier: Int;

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
