//
//  DicerollerApp.swift
//  Diceroller
//
//  Created by James McDonald on 08/03/2025.
//

import SwiftUI

@main
struct DicerollerApp: App {
    init() {
        _ = PhoneSyncManager.shared // Force init to run
    }
    
    var body: some Scene {
        WindowGroup {
            ContentView()
        }
    }
}
