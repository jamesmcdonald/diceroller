//
//  PhoneSyncManager.swift
//  Diceroller
//
//  Created by James McDonald on 08/03/2025.
//

import WatchConnectivity

/// Sends the phone's saved configurations to the watch whenever they change, and again
/// whenever the session activates or the watch app is installed, so the watch never misses them.
@MainActor
final class PhoneSyncManager: NSObject, WCSessionDelegate {
    private let store: RollStore

    init(store: RollStore) {
        self.store = store
        super.init()

        store.onLocalChange = { [weak self] configs in
            self?.send(configs)
        }

        if WCSession.isSupported() {
            let session = WCSession.default
            session.delegate = self
            session.activate()
        }
    }

    private func send(_ configs: [String: RollConfig]) {
        guard WCSession.isSupported() else { return }
        let session = WCSession.default
        guard session.activationState == .activated,
              session.isPaired,
              session.isWatchAppInstalled,
              let payload = SyncPayload.encode(configs) else {
            return
        }

        // Application context always holds the latest state, and the watch can read it
        // on launch even if it wasn't running when it was sent.
        do {
            try session.updateApplicationContext(payload)
        } catch {
            print("Failed to sync saved rolls to watch: \(error)")
        }
    }

    private func resendCurrentConfigs() {
        send(store.savedConfigs)
    }

    // MARK: - WCSessionDelegate

    nonisolated func session(_ session: WCSession, activationDidCompleteWith activationState: WCSessionActivationState, error: (any Error)?) {
        guard activationState == .activated else { return }
        Task { @MainActor in
            self.resendCurrentConfigs()
        }
    }

    nonisolated func sessionWatchStateDidChange(_ session: WCSession) {
        Task { @MainActor in
            self.resendCurrentConfigs()
        }
    }

    nonisolated func sessionDidBecomeInactive(_ session: WCSession) {}

    nonisolated func sessionDidDeactivate(_ session: WCSession) {
        // Required to support switching between paired watches.
        session.activate()
    }
}
