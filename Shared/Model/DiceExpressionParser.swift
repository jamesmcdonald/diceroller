//
//  DiceExpressionParser.swift
//  Diceroller
//

import Foundation

/// Why a dice expression couldn't be parsed, with messages suitable for showing under a text field.
enum DiceExpressionError: Error, Equatable, LocalizedError {
    case empty
    case unexpected(String)
    case missingSides
    case noDice
    case diceCount(Int)
    case sides(Int)
    case keep(String)
    case tooManyDice
    case tooManyTerms
    case numberTooLarge
    case advantageNeedsD20
    case advantageNeedsSingleD20

    var errorDescription: String? {
        switch self {
        case .empty:
            return "Enter a roll, like 1d20 + 5."
        case .unexpected(let text):
            return "Didn’t understand “\(text)”."
        case .missingSides:
            return "Add the number of sides after “d”, like d20."
        case .noDice:
            return "Add at least one die, like 1d20."
        case .diceCount:
            return "Use between 1 and \(DiceExpression.Limits.maxDicePerGroup) dice in each group."
        case .sides:
            return "Dice need between \(DiceExpression.Limits.sides.lowerBound) and \(DiceExpression.Limits.sides.upperBound) sides."
        case .keep(let message):
            return message
        case .tooManyDice:
            return "Use at most \(DiceExpression.Limits.maxTotalDice) dice in total."
        case .tooManyTerms:
            return "Use at most \(DiceExpression.Limits.maxTerms) parts in one roll."
        case .numberTooLarge:
            return "Numbers can be at most \(DiceExpression.Limits.maxConstant)."
        case .advantageNeedsD20:
            return "Advantage and disadvantage apply to a d20, like 1d20 + 5 (adv)."
        case .advantageNeedsSingleD20:
            return "Advantage and disadvantage need exactly one 1d20 to apply to. Use kh or kl for other dice, like 2d6kh1."
        }
    }
}

/// Parses dice notation. Case and spaces don't matter.
///
/// Grammar:
/// ```
/// expression := sign? term (sign term)* advantage?
/// term       := number | number? "d" sides keep?
/// sides      := number | "%"                      // d% is d100
/// keep       := ("kh" | "kl" | "dh" | "dl" | "k") number?   // count defaults to 1; "k" means "kh"
/// advantage  := "(" word ")" | word               // adv, advantage, dis, disadvantage
/// ```
/// Advantage needs exactly one plain "1d20" to apply to (see `DiceExpression.Advantage`).
/// Examples: `d20`, `1d20 + 5`, `2d6 + 1d4 - 1`, `4d6dl1`, `2d20kh1 + 3`, `1d20 + 1d4 + 7 (adv)`.
enum DiceExpressionParser {
    /// Parses `text` into an expression that can be rolled.
    ///
    /// With `allowingIncomplete`, empty text, rolls without dice, and misplaced advantage are accepted too.
    /// The editing buttons use this so they can build on whatever has been typed so far.
    static func parse(_ text: String, allowingIncomplete: Bool = false) throws -> DiceExpression {
        let tokens = try tokenize(text)
        if tokens.isEmpty {
            if allowingIncomplete { return DiceExpression(terms: []) }
            throw DiceExpressionError.empty
        }
        var parser = Parser(tokens: tokens, source: text)
        let expression = try parser.parseExpression()
        if !allowingIncomplete, let error = expression.validationError {
            throw error
        }
        return expression
    }

    // MARK: - Tokens

    enum Token: Equatable {
        case number(Int)
        case word(String)
        case plus
        case minus
        case percent
        case openParen
        case closeParen
    }

    struct LocatedToken {
        let token: Token
        let start: String.Index
    }

    static func tokenize(_ text: String) throws -> [LocatedToken] {
        var tokens: [LocatedToken] = []
        var index = text.startIndex

        while index < text.endIndex {
            let character = text[index]
            let start = index

            if character.isWhitespace {
                index = text.index(after: index)
            } else if character.isASCII, character.isNumber {
                while index < text.endIndex, text[index].isASCII, text[index].isNumber {
                    index = text.index(after: index)
                }
                // Overlong numbers become Int.max so the range checks report them as too large.
                let value = Int(text[start..<index]) ?? Int.max
                tokens.append(LocatedToken(token: .number(value), start: start))
            } else if character.isLetter {
                while index < text.endIndex, text[index].isLetter {
                    index = text.index(after: index)
                }
                tokens.append(LocatedToken(token: .word(text[start..<index].lowercased()), start: start))
            } else {
                let token: Token
                switch character {
                case "+": token = .plus
                // Accept typographic dashes too, since iOS keyboards sometimes substitute them.
                case "-", "−", "–", "—": token = .minus
                case "%": token = .percent
                case "(": token = .openParen
                case ")": token = .closeParen
                default: throw DiceExpressionError.unexpected(String(character))
                }
                tokens.append(LocatedToken(token: token, start: start))
                index = text.index(after: index)
            }
        }
        return tokens
    }

    // MARK: - Parser

    private struct Parser {
        let tokens: [LocatedToken]
        let source: String
        var position = 0

        init(tokens: [LocatedToken], source: String) {
            self.tokens = tokens
            self.source = source
        }

        private var current: Token? {
            position < tokens.count ? tokens[position].token : nil
        }

        private mutating func advance() {
            position += 1
        }

        /// The source text from the current token, for error messages.
        private var remainingText: String {
            guard position < tokens.count else { return "" }
            let rest = source[tokens[position].start...].trimmingCharacters(in: .whitespaces)
            return rest.count > 12 ? String(rest.prefix(12)) + "…" : rest
        }

        mutating func parseExpression() throws -> DiceExpression {
            var terms: [DiceExpression.Term] = []
            var sign = DiceExpression.Sign.plus

            switch current {
            case .plus: advance()
            case .minus: sign = .minus; advance()
            default: break
            }

            while true {
                terms.append(try parseTerm(sign: sign))
                if current == .plus {
                    sign = .plus
                } else if current == .minus {
                    sign = .minus
                } else {
                    break
                }
                advance()
            }

            let advantage = try parseAdvantage()

            guard current == nil else {
                throw DiceExpressionError.unexpected(remainingText)
            }
            guard terms.count <= DiceExpression.Limits.maxTerms else {
                throw DiceExpressionError.tooManyTerms
            }
            let totalDice = terms.reduce(0) { sum, term in
                guard case .dice(let count, _, _) = term.kind else { return sum }
                return sum + count
            }
            guard totalDice <= DiceExpression.Limits.maxTotalDice else {
                throw DiceExpressionError.tooManyDice
            }
            return DiceExpression(terms: terms, advantage: advantage)
        }

        private mutating func parseTerm(sign: DiceExpression.Sign) throws -> DiceExpression.Term {
            switch current {
            case .number(let value):
                advance()
                if current == .word("d") {
                    advance()
                    return DiceExpression.Term(sign: sign, kind: try parseDice(count: value))
                }
                guard value <= DiceExpression.Limits.maxConstant else {
                    throw DiceExpressionError.numberTooLarge
                }
                return DiceExpression.Term(sign: sign, kind: .constant(value))
            case .word("d"):
                advance()
                return DiceExpression.Term(sign: sign, kind: try parseDice(count: 1))
            case nil:
                // A trailing "+" or "-" with nothing after it.
                throw DiceExpressionError.unexpected(String(source.trimmingCharacters(in: .whitespaces).suffix(1)))
            default:
                throw DiceExpressionError.unexpected(remainingText)
            }
        }

        private mutating func parseDice(count: Int) throws -> DiceExpression.Term.Kind {
            guard (1...DiceExpression.Limits.maxDicePerGroup).contains(count) else {
                throw DiceExpressionError.diceCount(count)
            }

            let sides: Int
            switch current {
            case .number(let value):
                sides = value
            case .percent:
                sides = 100
            default:
                throw DiceExpressionError.missingSides
            }
            advance()
            guard DiceExpression.Limits.sides.contains(sides) else {
                throw DiceExpressionError.sides(sides)
            }

            return .dice(count: count, sides: sides, keep: try parseKeep(count: count))
        }

        private mutating func parseKeep(count: Int) throws -> DiceExpression.Keep? {
            guard case .word(let word) = current, ["k", "kh", "kl", "dh", "dl"].contains(word) else {
                return nil
            }
            advance()

            var amount = 1
            if case .number(let value) = current {
                amount = value
                advance()
            }

            switch word {
            case "k", "kh", "kl":
                guard (1...count).contains(amount) else {
                    throw DiceExpressionError.keep("Can’t keep \(amount) of \(count) \(count == 1 ? "die" : "dice").")
                }
                return word == "kl" ? .lowest(amount) : .highest(amount)
            default:
                guard amount >= 1, amount < count else {
                    throw DiceExpressionError.keep("Can’t drop \(amount) of \(count) \(count == 1 ? "die" : "dice"); at least one must count.")
                }
                return word == "dl" ? .dropLowest(amount) : .dropHighest(amount)
            }
        }

        private mutating func parseAdvantage() throws -> DiceExpression.Advantage {
            let hasParen = current == .openParen
            let startPosition = position
            if hasParen { advance() }

            guard case .word(let word) = current else {
                position = startPosition
                return .none
            }
            let advantage: DiceExpression.Advantage
            switch word {
            case "adv", "advantage": advantage = .advantage
            case "dis", "disadvantage": advantage = .disadvantage
            default:
                throw DiceExpressionError.unexpected(remainingText)
            }
            advance()

            if hasParen {
                guard current == .closeParen else {
                    throw DiceExpressionError.unexpected(current == nil ? "(" : remainingText)
                }
                advance()
            }
            return advantage
        }
    }
}
