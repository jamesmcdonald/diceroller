//
//  DiceExpression.swift
//  Diceroller
//

import Foundation

/// A dice expression such as "2d6 + 1d4 + 3", "4d6dl1" or "1d20 + 5 (adv)".
///
/// Expressions are stored and synced as their canonical text (see `description`) and parsed
/// again when loaded, so the saved format stays compact and readable.
struct DiceExpression: Hashable, Sendable {
    enum Sign: Hashable, Sendable {
        case plus, minus

        var multiplier: Int { self == .plus ? 1 : -1 }
    }

    /// Which dice to count from a group, for rolls like "4d6dl1" (drop the lowest)
    /// or "2d20kh1" (keep the highest).
    enum Keep: Hashable, Sendable {
        case highest(Int)
        case lowest(Int)
        case dropHighest(Int)
        case dropLowest(Int)
    }

    /// Advantage and disadvantage apply to the expression's single d20, as in D&D: it's rolled twice
    /// and the higher or lower result counts. Everything else is rolled once.
    enum Advantage: Hashable, Sendable, CaseIterable {
        case none, advantage, disadvantage
    }

    /// One part of an expression: a group of dice, or a fixed number.
    struct Term: Hashable, Sendable {
        enum Kind: Hashable, Sendable {
            case dice(count: Int, sides: Int, keep: Keep?)
            case constant(Int)
        }

        var sign: Sign
        var kind: Kind

        var isDice: Bool {
            if case .dice = kind { return true }
            return false
        }

        var isD20: Bool {
            if case .dice(_, 20, _) = kind { return true }
            return false
        }
    }

    /// Bounds that keep rolls quick to compute and readable.
    enum Limits {
        static let maxDicePerGroup = 100
        static let sides = 2...1000
        static let maxConstant = 1000
        static let maxTerms = 20
        static let maxTotalDice = 500
    }

    var terms: [Term]
    var advantage: Advantage = .none

    /// An expression like "2d6 + 3", as built by the watch's wheels and older saved rolls.
    static func simple(count: Int, sides: Int, modifier: Int) -> DiceExpression {
        var expression = DiceExpression(terms: [Term(sign: .plus, kind: .dice(count: count, sides: sides, keep: nil))])
        if modifier != 0 {
            expression.terms.append(Term(sign: modifier > 0 ? .plus : .minus, kind: .constant(abs(modifier))))
        }
        return expression
    }

    /// Whether the expression contains at least one die.
    var hasDice: Bool {
        terms.contains(where: \.isDice)
    }

    /// The part that advantage or disadvantage applies to: the only d20 group, which must be a plain,
    /// added "1d20". `nil` when rolling normally, or when there's no suitable d20.
    var advantageTermIndex: Int? {
        guard advantage != .none else { return nil }
        let d20Indices = terms.indices.filter { terms[$0].isD20 }
        guard d20Indices.count == 1, let index = d20Indices.first,
              terms[index].sign == .plus,
              case .dice(1, 20, .none) = terms[index].kind else {
            return nil
        }
        return index
    }

    /// Why this expression can't be rolled, or `nil` if it can.
    var validationError: DiceExpressionError? {
        if !hasDice {
            return .noDice
        }
        if advantage != .none && advantageTermIndex == nil {
            return terms.contains(where: \.isD20) ? .advantageNeedsSingleD20 : .advantageNeedsD20
        }
        return nil
    }

    /// The sum of the fixed numbers, for example 3 in "2d6 + 5 - 2".
    var modifier: Int {
        terms.reduce(0) { sum, term in
            guard case .constant(let value) = term.kind else { return sum }
            return sum + value * term.sign.multiplier
        }
    }

    // MARK: - Editing

    /// Adds one die with the given sides, increasing an existing plain group of the same die if there is one.
    /// New groups go after the last group of dice, so "1d20 + 5" plus a d4 becomes "1d20 + 1d4 + 5".
    func addingDie(sides: Int) -> DiceExpression {
        var copy = self
        let existing = copy.terms.firstIndex { term in
            guard term.sign == .plus, case .dice(let count, let termSides, .none) = term.kind else { return false }
            return termSides == sides && count < Limits.maxDicePerGroup
        }
        if let existing, case .dice(let count, _, _) = copy.terms[existing].kind {
            copy.terms[existing].kind = .dice(count: count + 1, sides: sides, keep: nil)
        } else {
            let insertIndex = copy.terms.lastIndex(where: \.isDice).map { $0 + 1 } ?? 0
            copy.terms.insert(Term(sign: .plus, kind: .dice(count: 1, sides: sides, keep: nil)), at: insertIndex)
        }
        return copy
    }

    /// Changes the last fixed number by `delta`, adding one if there isn't one and removing it if it reaches zero.
    func addingModifier(_ delta: Int) -> DiceExpression {
        var copy = self
        guard let index = copy.terms.lastIndex(where: { !$0.isDice }),
              case .constant(let value) = copy.terms[index].kind else {
            if delta != 0 {
                copy.terms.append(Term(sign: delta > 0 ? .plus : .minus, kind: .constant(min(abs(delta), Limits.maxConstant))))
            }
            return copy
        }
        let newValue = value * copy.terms[index].sign.multiplier + delta
        if newValue == 0 {
            copy.terms.remove(at: index)
        } else {
            copy.terms[index] = Term(sign: newValue > 0 ? .plus : .minus, kind: .constant(min(abs(newValue), Limits.maxConstant)))
        }
        return copy
    }

    // MARK: - Rolling

    /// Rolls the expression. With advantage or disadvantage, the d20 is rolled twice and one result is dropped.
    func roll<G: RandomNumberGenerator>(using generator: inout G) -> RollResult {
        let advantageIndex = advantageTermIndex
        var dieValues: [[Int]] = []
        for (index, term) in terms.enumerated() {
            guard case .dice(let count, let sides, _) = term.kind else { continue }
            let rolled = index == advantageIndex ? 2 : count
            dieValues.append((0..<rolled).map { _ in Int.random(in: 1...sides, using: &generator) })
        }
        return result(dieValues: dieValues)
    }

    /// Builds a result from known faces, given as one array per group of dice in order
    /// (with two faces for a d20 rolled with advantage or disadvantage).
    /// Rolling uses this after generating random faces; tests can call it with fixed faces.
    func result(dieValues: [[Int]]) -> RollResult {
        let advantageIndex = advantageTermIndex
        var groups = dieValues.makeIterator()
        let outcomes = terms.enumerated().map { index, term in
            switch term.kind {
            case .constant:
                return TermOutcome(term: term, dice: [])
            case .dice(_, let sides, let keep):
                let values = groups.next() ?? []
                let effectiveKeep = index == advantageIndex
                    ? (advantage == .advantage ? Keep.highest(1) : Keep.lowest(1))
                    : keep
                let kept = Self.keptIndices(of: values, keep: effectiveKeep)
                let dice = values.enumerated().map { dieIndex, value in
                    DieRoll(sides: sides, value: value, isKept: kept.contains(dieIndex))
                }
                return TermOutcome(term: term, dice: dice)
            }
        }
        return RollResult(expression: self, terms: outcomes)
    }

    /// The positions of the dice that count towards the total. Ties are broken by position,
    /// so with equal faces the earlier die is treated as lower.
    static func keptIndices(of values: [Int], keep: Keep?) -> Set<Int> {
        guard let keep else { return Set(values.indices) }
        let ascending = values.indices.sorted { (values[$0], $0) < (values[$1], $1) }
        switch keep {
        case .highest(let count): return Set(ascending.suffix(count))
        case .lowest(let count): return Set(ascending.prefix(count))
        case .dropHighest(let count): return Set(ascending.dropLast(count))
        case .dropLowest(let count): return Set(ascending.dropFirst(count))
        }
    }
}

// MARK: - Formatting

extension DiceExpression: CustomStringConvertible {
    /// Canonical text, for example "2d6 + 1d4 - 1" or "2d20kh1 + 5 (adv)". Parsing it gives back the same expression.
    var description: String {
        var text = ""
        for (index, term) in terms.enumerated() {
            let body = term.kind.notation
            if index == 0 {
                text = term.sign == .minus ? "-\(body)" : body
            } else {
                text += term.sign == .minus ? " - \(body)" : " + \(body)"
            }
        }
        switch advantage {
        case .none: break
        case .advantage: text += " (adv)"
        case .disadvantage: text += " (dis)"
        }
        return text.trimmingCharacters(in: .whitespaces)
    }
}

extension DiceExpression.Term.Kind {
    var notation: String {
        switch self {
        case .constant(let value):
            return "\(value)"
        case .dice(let count, let sides, let keep):
            return "\(count)d\(sides)" + (keep?.notation ?? "")
        }
    }
}

extension DiceExpression.Keep {
    var notation: String {
        switch self {
        case .highest(let count): return "kh\(count)"
        case .lowest(let count): return "kl\(count)"
        case .dropHighest(let count): return "dh\(count)"
        case .dropLowest(let count): return "dl\(count)"
        }
    }
}

// MARK: - Codable

extension DiceExpression: Codable {
    init(from decoder: any Decoder) throws {
        let container = try decoder.singleValueContainer()
        let text = try container.decode(String.self)
        do {
            self = try DiceExpressionParser.parse(text)
        } catch {
            throw DecodingError.dataCorruptedError(in: container, debugDescription: "Invalid dice expression “\(text)”: \(error)")
        }
    }

    func encode(to encoder: any Encoder) throws {
        var container = encoder.singleValueContainer()
        try container.encode(description)
    }
}
