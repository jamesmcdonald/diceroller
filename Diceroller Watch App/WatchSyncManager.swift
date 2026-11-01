//
//  WatchSyncManager.swift
//  Diceroller
//
//  Created by James McDonald on 08/03/2025.
//

import WatchConnectivity

/// Receives saved configurations from the phone and writes them into the store.
@MainActor
final class WatchSyncManager: NSObject, WCSessionDelegate {
    private let store: RollStore

    init(store: RollStore) {
        self.store = store
        super.init()

        if WCSession.isSupported() {
            let session = WCSession.default
            session.delegate = self
            session.activate()
        }
    }

    private func apply(_ configs: [RollConfig]) {
        store.replaceAll(with: configs)
    }

    // MARK: - WCSessionDelegate

    nonisolated func session(_ session: WCSession, activationDidCompleteWith activationState: WCSessionActivationState, error: (any Error)?) {
        // Pick up any context the phone sent while this app wasn't running.
        guard activationState == .activated,
              let configs = SyncPayload.decode(session.receivedApplicationContext) else {
            return
        }
        Task { @MainActor in
            self.apply(configs)
        }
    }

    nonisolated func session(_ session: WCSession, didReceiveApplicationContext applicationContext: [String: Any]) {
        guard let configs = SyncPayload.decode(applicationContext) else { return }
        Task { @MainActor in
            self.apply(configs)
        }
    }
}
