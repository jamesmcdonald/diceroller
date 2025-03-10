//
//  WatchSyncManager.swift
//  Diceroller
//
//  Created by James McDonald on 08/03/2025.
//

import ObjectiveC
import Foundation
import WatchConnectivity

class WatchSyncManager: NSObject, WCSessionDelegate, ObservableObject {
    
    static let shared = WatchSyncManager()
    @Published var savedConfigs: [String: RollConfig] = [:] {
        didSet {
            saveConfigsToStorage()
        }
    }
    
    private func saveConfigsToStorage() {
        if let data = try? JSONEncoder().encode(savedConfigs) {
            UserDefaults.standard.set(data, forKey: "savedRolls")
        }
    }
    
    private func loadConfigsFromStorage() {
        if let data = UserDefaults.standard.data(forKey: "savedRolls") {
            if let decodedRolls = try? JSONDecoder().decode([String: RollConfig].self, from: data) {
                DispatchQueue.main.async {
                    if self.savedConfigs != decodedRolls {
                        self.savedConfigs = decodedRolls
                    }
                }
            }
        }
    }

    private override init() {
        super.init()
        loadConfigsFromStorage()
        if WCSession.isSupported() {
            let session = WCSession.default
            if session.activationState == .notActivated {
                session.delegate = self
                session.activate()
            }
        }
    }

    func session(_ session: WCSession, activationDidCompleteWith activationState: WCSessionActivationState, error: (any Error)?) {
    }
    
    func session(_ session: WCSession, didReceiveApplicationContext applicationContext: [String: Any]) {
        handleIncomingData(applicationContext)
    }
    
    func session(_ session: WCSession, didReceiveUserInfo userInfo: [String : Any] = [:]) {
        handleIncomingData(userInfo)
    }
    
    func handleIncomingData(_ data: [String: Any]) {
        if let encodedRolls = data["savedRolls"] as? Data,
            let decodedRolls = try? JSONDecoder().decode([String: RollConfig].self, from: encodedRolls) {
            DispatchQueue.main.async {
                self.savedConfigs = decodedRolls
            }
        }
    }
}
