//
//  DicerollerTests.swift
//  DicerollerTests
//
//  Created by James McDonald on 08/03/2025.
//

import Foundation
import Testing
@testable import Diceroller

/// A deterministic SplitMix64 generator so rolls are repeatable in tests.
struct SeededGenerator: RandomNumberGenerator {
    private var state: UInt64

    init(seed: UInt64) {
        state = seed
    }

    mutating func next() -> UInt64 {
        state &+= 0x9E3779B97F4A7C15
        var z = state
        z = (z ^ (z >> 30)) &* 0xBF58476D1CE4E5B9
        z = (z ^ (z >> 27)) &* 0x94D049BB133111EB
        return z ^ (z >> 31)
    }
}

/// Parses an expression that the test expects to be valid.
func expr(_ text: String) throws -> DiceExpression {
    try DiceExpressionParser.parse(text)
}

/// Returns the parse error for text the test expects to be invalid.
func parseError(_ text: String) -> DiceExpressionError? {
    do {
        _ = try DiceExpressionParser.parse(text)
        return nil
    } catch {
        return error as? DiceExpressionError
    }
}

struct DiceExpressionParserTests {

    @Test(arguments: [
        ("d20", "1d20"),
        ("1d20+5", "1d20 + 5"),
        ("  2 D 6  +  3 ", "2d6 + 3"),
        ("2d6 + 1d4 - 1", "2d6 + 1d4 - 1"),
        ("1d20 - 1d4", "1d20 - 1d4"),
        ("-1 + 1d20", "-1 + 1d20"),
        ("+1d8", "1d8"),
        ("d%", "1d100"),
        ("4d6dl1", "4d6dl1"),
        ("4d6 DL", "4d6dl1"),
        ("2d20kh1+5", "2d20kh1 + 5"),
        ("2d20k", "2d20kh1"),
        ("3d6kl2", "3d6kl2"),
        ("5d10dh2", "5d10dh2"),
        ("1d20+5 adv", "1d20 + 5 (adv)"),
        ("1d20 + 5 (Disadvantage)", "1d20 + 5 (dis)"),
        ("1d20+1d4+5(adv)", "1d20 + 1d4 + 5 (adv)"),
        ("1d20 − 2", "1d20 - 2"),
        ("1d20 – 2", "1d20 - 2"),
        ("1d7", "1d7"),
    ])
    func parsesToCanonicalText(input: String, canonical: String) throws {
        let expression = try expr(input)
        #expect(expression.description == canonical)
        // Canonical text must parse back to the same expression, since that's how it's stored.
        #expect(try expr(canonical) == expression)
    }

    @Test func parsesStructure() throws {
        let expression = try expr("2d6 + 1d4kh1 - 3 + 1d20 (adv)")
        #expect(expression.terms == [
            .init(sign: .plus, kind: .dice(count: 2, sides: 6, keep: nil)),
            .init(sign: .plus, kind: .dice(count: 1, sides: 4, keep: .highest(1))),
            .init(sign: .minus, kind: .constant(3)),
            .init(sign: .plus, kind: .dice(count: 1, sides: 20, keep: nil)),
        ])
        #expect(expression.advantage == .advantage)
        #expect(expression.advantageTermIndex == 3)
    }

    @Test(arguments: [
        ("", DiceExpressionError.empty),
        ("   ", .empty),
        ("5", .noDice),
        ("2 + 3", .noDice),
        ("2d", .missingSides),
        ("d", .missingSides),
        ("0d6", .diceCount(0)),
        ("101d6", .diceCount(101)),
        ("1d1", .sides(1)),
        ("1d1001", .sides(1001)),
        ("1d20 + 1001", .numberTooLarge),
        ("1d20 + 99999999999999999999999", .numberTooLarge),
        ("1d20 +", .unexpected("+")),
        ("1d20 * 2", .unexpected("*")),
        ("1d20 + fish", .unexpected("fish")),
        ("1d20 5", .unexpected("5")),
        ("1d20 (adv", .unexpected("(")),
        ("1d6 + 1d4 adv", .advantageNeedsD20),
        ("2d20 adv", .advantageNeedsSingleD20),
        ("1d20 + 1d20 adv", .advantageNeedsSingleD20),
        ("2d20kh1 adv", .advantageNeedsSingleD20),
        ("5 - 1d20 adv", .advantageNeedsSingleD20),
    ])
    func rejectsInvalidInput(input: String, expected: DiceExpressionError) {
        #expect(parseError(input) == expected)
    }

    @Test func rejectsImpossibleKeepRules() {
        #expect(parseError("4d6kh5") == .keep("Can’t keep 5 of 4 dice."))
        #expect(parseError("4d6dl4") == .keep("Can’t drop 4 of 4 dice; at least one must count."))
        #expect(parseError("1d6dl1") == .keep("Can’t drop 1 of 1 die; at least one must count."))
    }

    @Test func rejectsTooManyDiceAndParts() {
        let manyGroups = Array(repeating: "100d6", count: 6).joined(separator: " + ")
        #expect(parseError(manyGroups) == .tooManyDice)

        let manyParts = "1d20" + String(repeating: " + 1", count: 20)
        #expect(parseError(manyParts) == .tooManyTerms)
    }

    @Test func incompleteParsingAllowsBuildingUp() throws {
        #expect(try DiceExpressionParser.parse("", allowingIncomplete: true).terms.isEmpty)
        #expect(try DiceExpressionParser.parse("+3", allowingIncomplete: true).modifier == 3)
        #expect(try DiceExpressionParser.parse("1d6 adv", allowingIncomplete: true).advantage == .advantage)
        #expect(throws: DiceExpressionError.self) {
            try DiceExpressionParser.parse("1d20 * 2", allowingIncomplete: true)
        }
    }

    @Test func everyErrorHasAMessage() {
        let errors: [DiceExpressionError] = [
            .empty, .unexpected("x"), .missingSides, .noDice, .diceCount(0), .sides(1), .keep("k"),
            .tooManyDice, .tooManyTerms, .numberTooLarge, .advantageNeedsD20, .advantageNeedsSingleD20,
        ]
        for error in errors {
            #expect(!(error.errorDescription ?? "").isEmpty)
        }
    }
}

struct DiceExpressionEditingTests {

    @Test func addingDieMergesPlainGroupsAndInsertsBeforeModifiers() throws {
        let start = try DiceExpressionParser.parse("", allowingIncomplete: true)
        let built = start
            .addingDie(sides: 20)
            .addingModifier(1)
            .addingModifier(1)
            .addingDie(sides: 4)
            .addingDie(sides: 4)

        #expect(built.description == "1d20 + 2d4 + 2")
    }

    @Test func addingDieDoesNotMergeIntoKeepOrSubtractedGroups() throws {
        #expect(try expr("4d6dl1").addingDie(sides: 6).description == "4d6dl1 + 1d6")
        #expect(try expr("1d20 - 1d6").addingDie(sides: 6).description == "1d20 - 1d6 + 1d6")
    }

    @Test func addingModifierCrossesZeroAndRemovesIt() throws {
        let expression = try expr("1d20 + 1")
        #expect(expression.addingModifier(-1).description == "1d20")
        #expect(expression.addingModifier(-3).description == "1d20 - 2")
        #expect(try expr("1d20").addingModifier(-1).description == "1d20 - 1")
    }

    @Test func modifierSumsConstants() throws {
        #expect(try expr("2d6 + 5 - 2").modifier == 3)
    }
}

struct DiceRollingTests {

    @Test(arguments: DieType.allCases)
    func rollsStayWithinDieFaces(dieType: DieType) {
        var generator = SeededGenerator(seed: 42)
        let expression = DiceExpression.simple(count: 50, sides: dieType.rawValue, modifier: 0)

        for _ in 0..<100 {
            let result = expression.roll(using: &generator)
            let dice = result.terms.flatMap(\.dice)
            #expect(dice.count == 50)
            #expect(dice.allSatisfy { (1...dieType.rawValue).contains($0.value) })
        }
    }

    @Test func sameSeedGivesSameResult() throws {
        let expression = try expr("4d6dl1 + 2d8 - 1d4 + 3")
        var first = SeededGenerator(seed: 1234)
        var second = SeededGenerator(seed: 1234)

        #expect(expression.roll(using: &first) == expression.roll(using: &second))
    }

    @Test func totalsAddAndSubtractParts() throws {
        let result = try expr("2d6 + 1d4 - 1d8 - 2").result(dieValues: [[3, 5], [4], [6]])
        #expect(result.total == 3 + 5 + 4 - 6 - 2)
        #expect(result.breakdown == "2d6 [3 + 5] + 1d4 [4] - 1d8 [6] - 2")
    }

    @Test func zeroAndNegativeTotalsAreReported() throws {
        #expect(try expr("1d4 - 1").result(dieValues: [[1]]).total == 0)
        #expect(try expr("1d4 - 3").result(dieValues: [[1]]).total == -2)
    }

    @Test func dropLowestAndKeepHighest() throws {
        let ability = try expr("4d6dl1").result(dieValues: [[3, 6, 1, 4]])
        #expect(ability.total == 13)
        #expect(ability.breakdown == "4d6dl1 [3 + 6 + 4, dropped 1]")

        let best = try expr("2d20kh1 + 2").result(dieValues: [[7, 15]])
        #expect(best.total == 17)
        #expect(best.natural == 15)

        let worst = try expr("3d6kl2").result(dieValues: [[5, 2, 6]])
        #expect(worst.total == 7)

        let dropHigh = try expr("3d6dh1").result(dieValues: [[5, 2, 6]])
        #expect(dropHigh.total == 7)
    }

    @Test func tiesDropOnlyOneDie() {
        #expect(DiceExpression.keptIndices(of: [2, 2, 5], keep: .dropLowest(1)) == [1, 2])
        #expect(DiceExpression.keptIndices(of: [4, 4], keep: .highest(1)) == [1])
    }

    @Test func advantageRollsOnlyTheD20Twice() throws {
        let expression = try expr("1d20 + 1d4 + 5 (adv)")
        let result = expression.result(dieValues: [[8, 17], [3]])

        #expect(result.total == 17 + 3 + 5)
        #expect(result.breakdown == "1d20 [17, dropped 8] + 1d4 [3] + 5")
    }

    @Test func disadvantageKeepsLowerD20() throws {
        let result = try expr("1d20 + 5 (dis)").result(dieValues: [[8, 17]])
        #expect(result.total == 13)
        #expect(result.natural == 8)
    }

    @Test func advantageGeneratesTwoD20sAndKeepsTheHigher() throws {
        let expression = try expr("1d20 + 1d4 (adv)")
        var generator = SeededGenerator(seed: 99)

        for _ in 0..<100 {
            let result = expression.roll(using: &generator)
            let d20s = result.terms[0].dice
            #expect(d20s.count == 2)
            #expect(result.terms[1].dice.count == 1)
            let kept = d20s.filter(\.isKept)
            #expect(kept.count == 1)
            #expect(kept.first?.value == d20s.map(\.value).max())
        }
    }

    @Test func naturalOnlyWhenOneDieCounts() throws {
        #expect(try expr("1d20 + 5").result(dieValues: [[20]]).isNaturalMax)
        #expect(try expr("1d20 + 5 (adv)").result(dieValues: [[1, 20]]).isNaturalMax)
        #expect(try expr("1d20 - 3").result(dieValues: [[1]]).isNaturalOne)
        #expect(try expr("1d20 + 1d4").result(dieValues: [[20], [4]]).natural == nil)
        #expect(try expr("2d6").result(dieValues: [[6, 6]]).natural == nil)
    }

    @Test func breakdownAbbreviatesLongRolls() throws {
        let long = try expr("12d6 - 1").result(dieValues: [Array(1...6) + Array(1...6)])
        #expect(long.breakdown == "12d6 [1 + 2 + 3 + 4 + 5 ... 5 + 6] - 1")
    }
}

struct RollConfigCodingTests {

    @Test func encodesExpressionAsText() throws {
        let config = RollConfig(name: "Attack", expression: try expr("1d20+5 adv"))
        let data = try JSONEncoder().encode(config)
        let json = try #require(String(data: data, encoding: .utf8))

        #expect(json.contains(#""expression":"1d20 + 5 (adv)""#))
        #expect(try JSONDecoder().decode(RollConfig.self, from: data) == config)
    }

    @Test func decodesConfigWithoutIDOrExpression() throws {
        let json = #"{"name":"Attack","numberOfDice":2,"dieType":20,"modifier":-1}"#
        let config = try JSONDecoder().decode(RollConfig.self, from: Data(json.utf8))

        #expect(config.name == "Attack")
        #expect(config.notation == "2d20 - 1")
    }

    @Test func decodesConfigWithIDButNoExpression() throws {
        let id = UUID()
        let json = #"{"id":"\#(id.uuidString)","name":"Fireball","numberOfDice":8,"dieType":6,"modifier":0}"#
        let config = try JSONDecoder().decode(RollConfig.self, from: Data(json.utf8))

        #expect(config.id == id)
        #expect(config.notation == "8d6")
    }

    @Test func rejectsInvalidStoredExpression() {
        let json = #"{"name":"Broken","expression":"1d20 * 2"}"#
        #expect(throws: DecodingError.self) {
            try JSONDecoder().decode(RollConfig.self, from: Data(json.utf8))
        }
    }
}

@MainActor
struct RollStoreTests {
    private let defaults: UserDefaults

    init() throws {
        defaults = try #require(UserDefaults(suiteName: "RollStoreTests-\(UUID().uuidString)"))
    }

    private let attack = RollConfig(name: "Attack", expression: .simple(count: 1, sides: 20, modifier: 5))
    private let fireball = RollConfig(name: "Fireball", expression: .simple(count: 8, sides: 6, modifier: 0))
    private let damage = RollConfig(name: "Damage", expression: .simple(count: 1, sides: 8, modifier: 3))

    @Test func configsPersistInOrderAcrossInstances() {
        let store = RollStore(defaults: defaults)
        store.add(fireball)
        store.add(attack)

        #expect(RollStore(defaults: defaults).configs == [fireball, attack])
    }

    @Test func updateKeepsPositionAndIdentity() {
        let store = RollStore(defaults: defaults)
        store.add(attack)
        store.add(fireball)

        var renamed = attack
        renamed.name = "Longsword"
        store.update(renamed)

        #expect(store.configs.map(\.name) == ["Longsword", "Fireball"])
        #expect(store.configs.first?.id == attack.id)
    }

    @Test func moveReorders() {
        let store = RollStore(defaults: defaults)
        store.add(attack)
        store.add(fireball)
        store.add(damage)

        store.move(fromOffsets: [2], toOffset: 0)

        #expect(store.configs == [damage, attack, fireball])
        #expect(RollStore(defaults: defaults).configs == [damage, attack, fireball])
    }

    @Test func deleteRemovesAndPersists() {
        let store = RollStore(defaults: defaults)
        store.add(attack)
        store.add(fireball)

        store.delete(ids: [attack.id])

        #expect(store.configs == [fireball])
        #expect(RollStore(defaults: defaults).configs == [fireball])
    }

    @Test func duplicateInsertsAfterOriginalWithUniqueName() {
        let store = RollStore(defaults: defaults)
        store.add(attack)
        store.add(fireball)

        let first = store.duplicate(attack)
        let second = store.duplicate(attack)

        #expect(store.configs.map(\.name) == ["Attack", "Attack 3", "Attack 2", "Fireball"])
        #expect(first.id != attack.id)
        #expect(second.id != first.id)
        #expect(first.notation == attack.notation)
    }

    @Test func nameCheckIgnoresCaseSpacesAndSelf() {
        let store = RollStore(defaults: defaults)
        store.add(attack)

        #expect(store.isNameTaken("  attack "))
        #expect(!store.isNameTaken("Attack", excluding: attack.id))
        #expect(!store.isNameTaken("Fireball"))
    }

    @Test func migratesLegacyDictionarySortedByName() throws {
        // The original format: a name-keyed dictionary, with no ids or expressions.
        let legacy = """
        {
          "Fireball": {"name": "Fireball", "numberOfDice": 8, "dieType": 6, "modifier": 0},
          "attack": {"name": "Attack", "numberOfDice": 1, "dieType": 20, "modifier": 5},
          "Damage": {"name": "Damage", "numberOfDice": 1, "dieType": 8, "modifier": 3}
        }
        """
        defaults.set(Data(legacy.utf8), forKey: RollStore.legacyStorageKey)

        let store = RollStore(defaults: defaults)

        #expect(store.configs.map(\.name) == ["Attack", "Damage", "Fireball"])
        #expect(store.configs.map(\.notation) == ["1d20 + 5", "1d8 + 3", "8d6"])
        #expect(defaults.data(forKey: RollStore.legacyStorageKey) == nil)
        #expect(RollStore(defaults: defaults).configs == store.configs)
    }

    @Test func upgradesArrayWithoutExpressionsAndKeepsIDs() throws {
        // The format before expressions: an ordered array with ids, but separate dice fields.
        let id = UUID()
        let stored = """
        [{"id": "\(id.uuidString)", "name": "Attack", "numberOfDice": 1, "dieType": 20, "modifier": 5}]
        """
        defaults.set(Data(stored.utf8), forKey: RollStore.storageKey)

        let store = RollStore(defaults: defaults)
        #expect(store.configs.map(\.id) == [id])
        #expect(store.configs.map(\.notation) == ["1d20 + 5"])

        // After any edit the new format is written, and it loads the same.
        store.add(fireball)
        #expect(RollStore(defaults: defaults).configs == store.configs)
    }

    @Test func localEditsNotifyButReplaceAllDoesNot() {
        let store = RollStore(defaults: defaults)
        var notifications: [[RollConfig]] = []
        store.onLocalChange = { notifications.append($0) }

        store.add(attack)
        store.delete(ids: [attack.id])
        store.replaceAll(with: [fireball])

        #expect(notifications == [[attack], []])
        #expect(store.configs == [fireball])
        #expect(RollStore(defaults: defaults).configs == [fireball])
    }

    @Test func syncPayloadRoundTripsInOrder() throws {
        let configs = [fireball, attack, damage]
        let payload = try #require(SyncPayload.encode(configs))

        #expect(SyncPayload.decode(payload) == configs)
        #expect(SyncPayload.decode([:]) == nil)
    }
}
