//
//  SyncPayload.swift
//  Diceroller
//

import Foundation

/// Encodes and decodes saved configurations for WatchConnectivity, so the phone and
/// watch agree on the dictionary key and format.
enum SyncPayload {
    private static let savedConfigsKey = "savedRolls"

    /// Builds a property-list-safe dictionary, or `nil` if encoding fails.
    static func encode(_ configs: [String: RollConfig]) -> [String: Any]? {
        guard let data = try? JSONEncoder().encode(configs) else { return nil }
        return [savedConfigsKey: data]
    }

    /// Extracts saved configurations from a received dictionary, or `nil` if none are present.
    static func decode(_ payload: [String: Any]) -> [String: RollConfig]? {
        guard let data = payload[savedConfigsKey] as? Data else { return nil }
        return try? JSONDecoder().decode([String: RollConfig].self, from: data)
    }
}
