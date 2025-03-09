//
//  RollConfig.swift
//  Diceroller
//
//  Created by James McDonald on 08/03/2025.
//

struct RollConfig : Codable, Equatable {
    var name: String;
    var numberOfDice: Int;
    var dieType: Int;
    var modifier: Int;
}
