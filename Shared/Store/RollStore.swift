//
//  RollStore.swift
//  Diceroller
//

import Foundation
import Observation

/// Holds the saved roll configurations and persists them to `UserDefaults`.
///
/// Both the phone and watch apps use this. The phone edits it directly, and the watch
/// receives a full copy from the phone via `replaceAll(with:)`.
@MainActor
@Observable
final class RollStore {
    /// Saved configurations, keyed by name.
    private(set) var savedConfigs: [String: RollConfig] = [:]

    /// Called after a local edit (save or delete), for example to sync the change to the watch.
    /// Not called for `replaceAll(with:)`, so incoming syncs aren't echoed back.
    @ObservationIgnored var onLocalChange: (([String: RollConfig]) -> Void)?

    @ObservationIgnored private let defaults: UserDefaults
    @ObservationIgnored private let storageKey: String

    init(defaults: UserDefaults = .standard, storageKey: String = "savedConfigs") {
        self.defaults = defaults
        self.storageKey = storageKey
        load()
    }

    /// Names of the saved configurations in alphabetical order.
    var sortedNames: [String] {
        savedConfigs.keys.sorted()
    }

    /// Saves a configuration under its name, replacing any existing one with the same name.
    func save(_ config: RollConfig) {
        savedConfigs[config.name] = config
        persist()
        onLocalChange?(savedConfigs)
    }

    /// Deletes the configurations with the given names.
    func delete(names: [String]) {
        for name in names {
            savedConfigs.removeValue(forKey: name)
        }
        persist()
        onLocalChange?(savedConfigs)
    }

    /// Replaces every saved configuration, for example with a copy synced from another device.
    func replaceAll(with configs: [String: RollConfig]) {
        guard configs != savedConfigs else { return }
        savedConfigs = configs
        persist()
    }

    private func load() {
        guard let data = defaults.data(forKey: storageKey),
              let decoded = try? JSONDecoder().decode([String: RollConfig].self, from: data) else {
            return
        }
        savedConfigs = decoded
    }

    private func persist() {
        if let data = try? JSONEncoder().encode(savedConfigs) {
            defaults.set(data, forKey: storageKey)
        }
    }
}
