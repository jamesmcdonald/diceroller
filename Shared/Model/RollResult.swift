//
//  RollResult.swift
//  Diceroller
//

/// The outcome of rolling a `RollConfig`.
struct RollResult: Equatable {
    /// The type of die that was rolled.
    let dieType: DieType

    /// The face shown on each die, in the order they were rolled.
    let rolls: [Int]

    /// The modifier added to the sum of the dice.
    let modifier: Int

    /// The sum of all dice plus the modifier. This can be zero or negative.
    var total: Int {
        rolls.reduce(0, +) + modifier
    }

    /// The unmodified face when exactly one die was rolled, otherwise `nil`.
    var natural: Int? {
        rolls.count == 1 ? rolls.first : nil
    }

    /// Whether a single die landed on its highest face.
    var isNaturalMax: Bool {
        natural == dieType.rawValue
    }

    /// Whether a single die landed on a 1.
    var isNaturalOne: Bool {
        natural == 1
    }

    /// The individual dice and modifier, for example "2D6 [3 + 5] + 2".
    /// Long lists of dice are abbreviated to the first five and last two.
    var breakdown: String {
        let dice = "\(rolls.count)\(dieType.description)"
        let faces: String
        if rolls.count > 10 {
            let firstFew = rolls.prefix(5).map(\.description).joined(separator: " + ")
            let lastFew = rolls.suffix(2).map(\.description).joined(separator: " + ")
            faces = "\(firstFew) ... \(lastFew)"
        } else {
            faces = rolls.map(\.description).joined(separator: " + ")
        }
        let modifierText = modifier == 0 ? "" : (modifier > 0 ? " + \(modifier)" : " - \(abs(modifier))")
        return "\(dice) [\(faces)]\(modifierText)"
    }
}
