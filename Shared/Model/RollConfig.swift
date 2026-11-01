//
//  RollConfig.swift
//  Diceroller
//
//  Created by James McDonald on 08/03/2025.
//

import Foundation

/// A saved roll: a name and the dice expression to roll.
struct RollConfig : Codable, Hashable, Identifiable {
    /// The number of dice offered by the watch's custom roll wheel.
    static let numberOfDiceRange = 1...50

    /// The modifiers offered by the watch's custom roll wheel.
    static let modifierRange = -20...20

    /// Stable identity, so a saved roll can be renamed or reordered without becoming a different roll.
    let id: UUID

    /// The name of this configuration, for example "Attack" or "Fireball"
    var name: String

    /// What to roll, for example "1d20 + 5".
    var expression: DiceExpression

    init(id: UUID = UUID(), name: String, expression: DiceExpression) {
        self.id = id
        self.name = name
        self.expression = expression
    }

    private enum CodingKeys: String, CodingKey {
        case id, name, expression
        // Fields used before expressions, when a roll was always "NdX + modifier".
        case numberOfDice, dieType, modifier
    }

    /// Decodes a configuration, upgrading data saved before ids or expressions existed.
    init(from decoder: any Decoder) throws {
        let container = try decoder.container(keyedBy: CodingKeys.self)
        id = try container.decodeIfPresent(UUID.self, forKey: .id) ?? UUID()
        name = try container.decode(String.self, forKey: .name)
        if let expression = try container.decodeIfPresent(DiceExpression.self, forKey: .expression) {
            self.expression = expression
        } else {
            let numberOfDice = try container.decode(Int.self, forKey: .numberOfDice)
            let dieType = try container.decode(DieType.self, forKey: .dieType)
            let modifier = try container.decode(Int.self, forKey: .modifier)
            expression = .simple(count: numberOfDice, sides: dieType.rawValue, modifier: modifier)
        }
    }

    func encode(to encoder: any Encoder) throws {
        var container = encoder.container(keyedBy: CodingKeys.self)
        try container.encode(id, forKey: .id)
        try container.encode(name, forKey: .name)
        try container.encode(expression, forKey: .expression)
    }

    /// Dice notation for this configuration, for example "2d6 + 3".
    var notation: String {
        expression.description
    }

    /// Rolls the dice using the system random number generator.
    func roll() -> RollResult {
        var generator = SystemRandomNumberGenerator()
        return roll(using: &generator)
    }

    /// Rolls the dice using the given generator, so tests can supply a seeded one.
    func roll<G: RandomNumberGenerator>(using generator: inout G) -> RollResult {
        expression.roll(using: &generator)
    }
}
