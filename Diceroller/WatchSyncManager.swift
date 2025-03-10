//
//  WatchSyncManager.swift
//  Diceroller
//
//  Created by James McDonald on 08/03/2025.
//

import WatchConnectivity

class WatchSyncManager: NSObject, WCSessionDelegate, ObservableObject {
    func session(_ session: WCSession, activationDidCompleteWith activationState: WCSessionActivationState, error: (any Error)?) {
        
    }
    
    static let shared = WatchSyncManager()
    @Published var savedConfigs: [String: RollConfig] = [:]

    private override init() {
        super.init()
        if WCSession.isSupported() {
           let session = WCSession.default
           if session.activationState == .notActivated {
               session.delegate = self
               session.activate()
           }
       }
    }

    func syncSavedRolls(_ rolls: [String: RollConfig]) {
        let encodedRolls = try? JSONEncoder().encode(rolls)
        do {
            try WCSession.default.updateApplicationContext(["savedRolls": encodedRolls as Any])
        } catch {
            WCSession.default.transferUserInfo(["savedRolls": encodedRolls as Any])
        }
    }

    func session(_ session: WCSession, didReceiveUserInfo userInfo: [String : Any] = [:]) {
        if let data = userInfo["savedRolls"] as? Data,
           let decodedRolls = try? JSONDecoder().decode([String: RollConfig].self, from: data) {
            DispatchQueue.main.async {
                self.savedConfigs = decodedRolls
            }
        }
    }

    func sessionDidBecomeInactive(_ session: WCSession) {}
    func sessionDidDeactivate(_ session: WCSession) {
        WCSession.default.activate()
    }
}
