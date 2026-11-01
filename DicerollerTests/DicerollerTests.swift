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

@MainActor
struct RollStoreTests {
    private let defaults: UserDefaults

    init() throws {
        defaults = try #require(UserDefaults(suiteName: "RollStoreTests-\(UUID().uuidString)"))
    }

    private let attack = RollConfig(name: "Attack", numberOfDice: 1, dieType: .d20, modifier: 5)
    private let fireball = RollConfig(name: "Fireball", numberOfDice: 8, dieType: .d6, modifier: 0)

    @Test func savedConfigsPersistAcrossInstances() {
        let store = RollStore(defaults: defaults)
        store.save(attack)
        store.save(fireball)

        let reloaded = RollStore(defaults: defaults)

        #expect(reloaded.savedConfigs == ["Attack": attack, "Fireball": fireball])
        #expect(reloaded.sortedNames == ["Attack", "Fireball"])
    }

    @Test func deleteRemovesAndPersists() {
        let store = RollStore(defaults: defaults)
        store.save(attack)
        store.save(fireball)

        store.delete(names: ["Attack"])

        #expect(store.sortedNames == ["Fireball"])
        #expect(RollStore(defaults: defaults).sortedNames == ["Fireball"])
    }

    @Test func localEditsNotifyButReplaceAllDoesNot() {
        let store = RollStore(defaults: defaults)
        var notifications: [[String: RollConfig]] = []
        store.onLocalChange = { notifications.append($0) }

        store.save(attack)
        store.delete(names: ["Attack"])
        store.replaceAll(with: ["Fireball": fireball])

        #expect(notifications == [["Attack": attack], [:]])
        #expect(store.savedConfigs == ["Fireball": fireball])
        #expect(RollStore(defaults: defaults).savedConfigs == ["Fireball": fireball])
    }

    @Test func syncPayloadRoundTrips() throws {
        let configs = ["Attack": attack, "Fireball": fireball]
        let payload = try #require(SyncPayload.encode(configs))

        #expect(SyncPayload.decode(payload) == configs)
        #expect(SyncPayload.decode([:]) == nil)
    }
}
