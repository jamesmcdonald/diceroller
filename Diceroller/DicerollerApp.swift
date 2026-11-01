//
//  DicerollerApp.swift
//  Diceroller
//
//  Created by James McDonald on 08/03/2025.
//

import SwiftUI

@main
struct DicerollerApp: App {
    @State private var store: RollStore
    @State private var syncManager: PhoneSyncManager

    init() {
        let store = RollStore()
        _store = State(initialValue: store)
        _syncManager = State(initialValue: PhoneSyncManager(store: store))
    }

    var body: some Scene {
        WindowGroup {
            ContentView()
                .environment(store)
        }
    }
}
