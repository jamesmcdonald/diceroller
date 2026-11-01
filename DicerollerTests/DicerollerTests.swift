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

struct RollConfigTests {

    @Test(arguments: DieType.allCases)
    func rollsStayWithinDieFaces(dieType: DieType) {
        var generator = SeededGenerator(seed: 42)
        let config = RollConfig(name: "", numberOfDice: 50, dieType: dieType, modifier: 0)

        for _ in 0..<100 {
            let result = config.roll(using: &generator)
            #expect(result.rolls.count == 50)
            #expect(result.rolls.allSatisfy { (1...dieType.rawValue).contains($0) })
        }
    }

    @Test func totalIncludesModifier() {
        var generator = SeededGenerator(seed: 7)
        let config = RollConfig(name: "", numberOfDice: 3, dieType: .d6, modifier: -4)

        let result = config.roll(using: &generator)

        #expect(result.total == result.rolls.reduce(0, +) - 4)
        #expect(result.modifier == -4)
        #expect(result.dieType == .d6)
    }

    @Test func sameSeedGivesSameRolls() {
        let config = RollConfig(name: "", numberOfDice: 10, dieType: .d20, modifier: 2)
        var first = SeededGenerator(seed: 1234)
        var second = SeededGenerator(seed: 1234)

        #expect(config.roll(using: &first) == config.roll(using: &second))
    }
}

struct RollResultTests {

    @Test func zeroAndNegativeTotalsAreReported() {
        #expect(RollResult(dieType: .d4, rolls: [1], modifier: -1).total == 0)
        #expect(RollResult(dieType: .d4, rolls: [1], modifier: -3).total == -2)
    }

    @Test func naturalOnlyForSingleDie() {
        #expect(RollResult(dieType: .d20, rolls: [17], modifier: 5).natural == 17)
        #expect(RollResult(dieType: .d20, rolls: [17, 3], modifier: 5).natural == nil)
    }

    @Test func naturalMaxAndOneIgnoreModifier() {
        let crit = RollResult(dieType: .d20, rolls: [20], modifier: -3)
        #expect(crit.isNaturalMax)
        #expect(!crit.isNaturalOne)

        let fumble = RollResult(dieType: .d20, rolls: [1], modifier: 5)
        #expect(fumble.isNaturalOne)
        #expect(!fumble.isNaturalMax)

        let multiple = RollResult(dieType: .d6, rolls: [6, 6], modifier: 0)
        #expect(!multiple.isNaturalMax)
    }
}

struct RollConfigNotationTests {

    @Test func notationIncludesSignedModifier() {
        #expect(RollConfig(name: "", numberOfDice: 2, dieType: .d6, modifier: 0).notation == "2D6")
        #expect(RollConfig(name: "", numberOfDice: 1, dieType: .d20, modifier: 5).notation == "1D20 + 5")
        #expect(RollConfig(name: "", numberOfDice: 3, dieType: .d8, modifier: -2).notation == "3D8 - 2")
    }

    @Test func breakdownAbbreviatesLongRolls() {
        let short = RollResult(dieType: .d6, rolls: [3, 5], modifier: 2)
        #expect(short.breakdown == "2D6 [3 + 5] + 2")

        let long = RollResult(dieType: .d6, rolls: Array(1...6) + Array(1...6), modifier: -1)
        #expect(long.breakdown == "12D6 [1 + 2 + 3 + 4 + 5 ... 5 + 6] - 1")
    }

    @Test func decodesLegacyConfigWithoutID() throws {
        let json = #"{"name":"Attack","numberOfDice":1,"dieType":20,"modifier":5}"#
        let config = try JSONDecoder().decode(RollConfig.self, from: Data(json.utf8))

        #expect(config.name == "Attack")
        #expect(config.dieType == .d20)
        #expect(config.modifier == 5)
    }
}

@MainActor
struct RollStoreTests {
    private let defaults: UserDefaults

    init() throws {
        defaults = try #require(UserDefaults(suiteName: "RollStoreTests-\(UUID().uuidString)"))
    }

    private let attack = RollConfig(name: "Attack", numberOfDice: 1, dieType: .d20, modifier: 5)
    private let fireball = RollConfig(name: "Fireball", numberOfDice: 8, dieType: .d6, modifier: 0)
    private let damage = RollConfig(name: "Damage", numberOfDice: 1, dieType: .d8, modifier: 3)

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
        let legacy = ["Fireball": fireball, "attack": attack, "Damage": damage]
        defaults.set(try JSONEncoder().encode(legacy), forKey: RollStore.legacyStorageKey)

        let store = RollStore(defaults: defaults)

        #expect(store.configs.map(\.name) == ["Attack", "Damage", "Fireball"])
        #expect(defaults.data(forKey: RollStore.legacyStorageKey) == nil)
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
