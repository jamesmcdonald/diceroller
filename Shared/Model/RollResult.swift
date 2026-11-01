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
}
