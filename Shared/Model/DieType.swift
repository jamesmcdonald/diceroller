//
//  DieType.swift
//  Diceroller
//
//  Created by James McDonald on 09/03/2025.
//

/// DieType defines the set of supported dice.
enum DieType : Int, Codable, CaseIterable {
    case d4 = 4
    case d6 = 6
    case d8 = 8
    case d10 = 10
    case d12 = 12
    case d20 = 20
    case d100 = 100
    
    var description: String {
        "D\(rawValue)"
    }
    
    static let defaultDie: DieType = d20
}
