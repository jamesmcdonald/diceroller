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
}
