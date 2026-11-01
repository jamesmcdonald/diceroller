//
//  Diceroller_WatchApp.swift
//  Diceroller Watch App
//
//  Created by James McDonald on 08/03/2025.
//

import SwiftUI

@main
struct Diceroller_WatchApp: App {
    init() {
        _ = WatchSyncManager.shared
    }
    
    var body: some Scene {
        WindowGroup {
            WatchDiceRollerView()
        }
    }
}
