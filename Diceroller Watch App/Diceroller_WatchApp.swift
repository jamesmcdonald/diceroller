//
//  Diceroller_WatchApp.swift
//  Diceroller Watch App
//
//  Created by James McDonald on 08/03/2025.
//

import SwiftUI

@main
struct Diceroller_WatchApp: App {
    @State private var store: RollStore
    @State private var syncManager: WatchSyncManager

    init() {
        let store = RollStore()
        _store = State(initialValue: store)
        _syncManager = State(initialValue: WatchSyncManager(store: store))
    }

    var body: some Scene {
        WindowGroup {
            WatchDiceRollerView()
                .environment(store)
        }
    }
}
