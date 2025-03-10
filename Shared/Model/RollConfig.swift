//
//  RollConfig.swift
//  Diceroller
//
//  Created by James McDonald on 08/03/2025.
//

/// A configuration for a saved roll, defining the number and type of dice, and any modifier.
struct RollConfig : Codable, Equatable {
    /// The name of this configuration, for example "Attack" or "Fireball"
    var name: String;
    
    /// The number of dice to roll.
    var numberOfDice: Int;
    
    /// The type of die.
    var dieType: DieType;
    
    /// Any modifier, such as a +3 to an attack roll.
    var modifier: Int;
    
    /// Rolls the dice, returning a total and a list of the rolls
    func roll() -> (total: Int, rolls: [Int]) {
        let rolls = (1...numberOfDice).map { _ in
            Int.random(in: 1...dieType.rawValue)
        }
        let total = rolls.reduce(0, +) + modifier
        return (total, rolls)
    }
}
