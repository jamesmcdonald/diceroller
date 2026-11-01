//
//  RollResult.swift
//  Diceroller
//

/// A single die that was rolled.
struct DieRoll: Hashable, Sendable {
    let sides: Int
    let value: Int

    /// False for dice dropped by a keep or drop rule such as "4d6dl1".
    let isKept: Bool
}

/// The result of one part of an expression.
struct TermOutcome: Hashable, Sendable {
    let term: DiceExpression.Term

    /// Every die rolled for this part, in order, including dropped ones. Empty for fixed numbers.
    let dice: [DieRoll]

    /// This part's contribution to the total, including its sign.
    var value: Int {
        let magnitude: Int
        switch term.kind {
        case .constant(let constant):
            magnitude = constant
        case .dice:
            magnitude = dice.filter(\.isKept).reduce(0) { $0 + $1.value }
        }
        return magnitude * term.sign.multiplier
    }

    /// For example "2d6 [3 + 5]", "4d6dl1 [6 + 4 + 3, dropped 1]" or "3".
    /// Long lists of dice are shortened to the first five and last two.
    var breakdown: String {
        guard term.isDice else { return term.kind.notation }

        let kept = dice.filter(\.isKept).map(\.value)
        let dropped = dice.filter { !$0.isKept }.map(\.value)

        var faces = Self.abbreviated(kept)
        if !dropped.isEmpty {
            faces += ", dropped " + Self.abbreviated(dropped)
        }
        return "\(term.kind.notation) [\(faces)]"
    }

    private static func abbreviated(_ values: [Int]) -> String {
        if values.count > 10 {
            let firstFew = values.prefix(5).map(\.description).joined(separator: " + ")
            let lastFew = values.suffix(2).map(\.description).joined(separator: " + ")
            return "\(firstFew) ... \(lastFew)"
        }
        return values.map(\.description).joined(separator: " + ")
    }
}

/// The outcome of rolling a `RollConfig`.
struct RollResult: Hashable, Sendable {
    let expression: DiceExpression

    /// The result of each part of the expression, in order.
    let terms: [TermOutcome]

    /// The sum of all parts. This can be zero or negative.
    var total: Int {
        terms.reduce(0) { $0 + $1.value }
    }

    /// Every part with its dice, for example "1d20 [17, dropped 4] + 1d4 [2] + 5".
    var breakdown: String {
        var text = ""
        for (index, term) in terms.enumerated() {
            let part = term.breakdown
            if index == 0 {
                text = term.term.sign == .minus ? "-\(part)" : part
            } else {
                text += term.term.sign == .minus ? " - \(part)" : " + \(part)"
            }
        }
        return text
    }

    /// The only die that counts, if exactly one does. For example the d20 in "1d20 + 5", "2d20kh1 + 5"
    /// or "1d20 + 5 (adv)", but not in "1d20 + 1d4".
    var naturalDie: DieRoll? {
        let counted = terms.flatMap { $0.dice.filter(\.isKept) }
        return counted.count == 1 ? counted.first : nil
    }

    /// The unmodified face of `naturalDie`, if there is one.
    var natural: Int? {
        naturalDie?.value
    }

    /// Whether the single counted die landed on its highest face.
    var isNaturalMax: Bool {
        naturalDie.map { $0.value == $0.sides } ?? false
    }

    /// Whether the single counted die landed on a 1.
    var isNaturalOne: Bool {
        naturalDie?.value == 1
    }
}
