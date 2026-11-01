//
//  SyncPayload.swift
//  Diceroller
//

import Foundation

/// Encodes and decodes saved configurations for WatchConnectivity, so the phone and
/// watch agree on the dictionary key and format.
enum SyncPayload {
    /// Holds an ordered array of configurations. The key changed from "savedRolls" when the
    /// format moved from a name-keyed dictionary to an array, so old and new builds ignore each other.
    private static let configsKey = "rollConfigs"

    /// Builds a property-list-safe dictionary, or `nil` if encoding fails.
    static func encode(_ configs: [RollConfig]) -> [String: Any]? {
        guard let data = try? JSONEncoder().encode(configs) else { return nil }
        return [configsKey: data]
    }

    /// Extracts saved configurations from a received dictionary, or `nil` if none are present.
    static func decode(_ payload: [String: Any]) -> [RollConfig]? {
        guard let data = payload[configsKey] as? Data else { return nil }
        return try? JSONDecoder().decode([RollConfig].self, from: data)
    }
}
