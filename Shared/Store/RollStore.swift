//
//  RollStore.swift
//  Diceroller
//

import Foundation
import Observation

/// Holds the saved roll configurations, in the user's chosen order, and persists them to `UserDefaults`.
///
/// Both the phone and watch apps use this. The phone edits it directly, and the watch
/// receives a full copy from the phone via `replaceAll(with:)`.
@MainActor
@Observable
final class RollStore {
    /// Saved configurations in display order.
    private(set) var configs: [RollConfig] = []

    /// Called after a local edit, for example to sync the change to the watch.
    /// Not called for `replaceAll(with:)`, so incoming syncs aren't echoed back.
    @ObservationIgnored var onLocalChange: (([RollConfig]) -> Void)?

    @ObservationIgnored private let defaults: UserDefaults

    static let storageKey = "rollConfigs"

    /// The key used before saved rolls had ids and an order, when they were stored as a name-keyed dictionary.
    static let legacyStorageKey = "savedConfigs"

    init(defaults: UserDefaults = .standard) {
        self.defaults = defaults
        load()
    }

    /// Adds a new configuration to the end of the list.
    func add(_ config: RollConfig) {
        configs.append(config)
        commit()
    }

    /// Replaces the configuration with the same id. Does nothing if it isn't found.
    func update(_ config: RollConfig) {
        guard let index = configs.firstIndex(where: { $0.id == config.id }) else { return }
        configs[index] = config
        commit()
    }

    /// Inserts a copy of a configuration straight after it, with a unique name.
    @discardableResult
    func duplicate(_ config: RollConfig) -> RollConfig {
        let copy = RollConfig(
            name: uniqueName(basedOn: config.name),
            numberOfDice: config.numberOfDice,
            dieType: config.dieType,
            modifier: config.modifier
        )
        let index = configs.firstIndex(where: { $0.id == config.id }).map { $0 + 1 } ?? configs.endIndex
        configs.insert(copy, at: index)
        commit()
        return copy
    }

    /// Deletes the configurations with the given ids.
    func delete(ids: Set<RollConfig.ID>) {
        configs.removeAll { ids.contains($0.id) }
        commit()
    }

    /// Reorders configurations, matching `List`'s `onMove` arguments.
    func move(fromOffsets source: IndexSet, toOffset destination: Int) {
        configs.move(fromOffsets: source, toOffset: destination)
        commit()
    }

    /// Replaces every saved configuration, for example with a copy synced from another device.
    func replaceAll(with configs: [RollConfig]) {
        guard configs != self.configs else { return }
        self.configs = configs
        persist()
    }

    /// Whether another configuration already uses this name, ignoring case and surrounding spaces.
    func isNameTaken(_ name: String, excluding id: RollConfig.ID? = nil) -> Bool {
        let normalized = Self.normalize(name)
        return configs.contains { $0.id != id && Self.normalize($0.name) == normalized }
    }

    /// Returns `name` if it's free, otherwise the first free "name 2", "name 3", and so on.
    func uniqueName(basedOn name: String) -> String {
        guard isNameTaken(name) else { return name }
        var suffix = 2
        while isNameTaken("\(name) \(suffix)") {
            suffix += 1
        }
        return "\(name) \(suffix)"
    }

    private static func normalize(_ name: String) -> String {
        name.trimmingCharacters(in: .whitespacesAndNewlines).lowercased()
    }

    private func commit() {
        persist()
        onLocalChange?(configs)
    }

    private func load() {
        if let data = defaults.data(forKey: Self.storageKey),
           let decoded = try? JSONDecoder().decode([RollConfig].self, from: data) {
            configs = decoded
            return
        }

        // Migrate from the old name-keyed dictionary, ordering by name as the old UI did.
        if let data = defaults.data(forKey: Self.legacyStorageKey),
           let legacy = try? JSONDecoder().decode([String: RollConfig].self, from: data) {
            configs = legacy.values.sorted { $0.name.localizedStandardCompare($1.name) == .orderedAscending }
            persist()
            defaults.removeObject(forKey: Self.legacyStorageKey)
        }
    }

    private func persist() {
        if let data = try? JSONEncoder().encode(configs) {
            defaults.set(data, forKey: Self.storageKey)
        }
    }
}

#if DEBUG
extension RollStore {
    /// A store with sample rolls for SwiftUI previews, kept apart from real saved data.
    static func preview() -> RollStore {
        let store = RollStore(defaults: UserDefaults(suiteName: "RollStorePreview") ?? .standard)
        store.replaceAll(with: [
            RollConfig(name: "Attack", numberOfDice: 1, dieType: .d20, modifier: 5),
            RollConfig(name: "Longsword", numberOfDice: 1, dieType: .d8, modifier: 3),
            RollConfig(name: "Fireball", numberOfDice: 8, dieType: .d6, modifier: 0),
        ])
        return store
    }
}
#endif
