//
//  ContentView.swift
//  Diceroller
//
//  Created by James McDonald on 08/03/2025.
//

import SwiftUI

struct ContentView: View {
    @State private var numberOfDice: Int = 1;
    @State private var dieSelector: Int = 1;
    @State private var modifier: Int = 0;
    @State private var rolls: [Int] = [];
    @State private var result: Int = 0;
    @State private var rollsText: String = "";
    @State private var newConfigName = ""

    @State private var showingRollCollection: Bool = false;
    @State private var showingSaveAlert = false
    
    let dice: [Int] = [4,6,8,10,12,20,100];
    let taglines: [String] = [
        "It's dicy",
        "Now with 50% more random",
        "Rolling responsibly since 2025",
        "Let fate decide… or blame the dice",
        "100% fair, 0% forgiving",
        "Now with 50% less mercy!",
        "The dice giveth, the dice taketh away",
        "Randomness you can trust",
        "Guaranteed to roll better than you",
        "Numbers are hard, let me do it",
        "Roll high, live large",
        "Only a 1 in 20 chance of critical miss!"
    ]
    @State private var savedConfigs: [String: RollConfig] = [:]
    
    var modifierText: String {
        if modifier == 0 {
            return ""
        }
        return modifier > 0 ? " + \(modifier)" : " - \(abs(modifier))"
    }
    
    @State private var taglineIndex: Int = 0
    
    func rollDice() -> [Int] {
        var result: [Int] = [];
        if numberOfDice < 0 {
            return []
        }
        for _ in 0..<Int(numberOfDice) {
            result.append(Int.random(in: 1...dice[dieSelector]))
        }
        return result
    }
    
    func reset() {
        numberOfDice = 1
        dieSelector = 1
        modifier = 0
        result = 0
        rolls.removeAll()
        rollsText = ""
    }
    
    func startTaglineTimer() {
        Timer.scheduledTimer(withTimeInterval: 300, repeats: true) { _ in
            taglineIndex = Int.random(in: 0..<taglines.count)
        }
    }
    
    func saveConfigs() {
        if let encoded = try? JSONEncoder().encode(savedConfigs) {
            UserDefaults.standard.set(encoded, forKey: "savedConfigs")
        }
        WatchSyncManager.shared.syncSavedRolls(savedConfigs)
    }

    func loadConfigs() {
        if let savedData = UserDefaults.standard.data(forKey: "savedConfigs"),
           let decoded = try? JSONDecoder().decode([String: RollConfig].self, from: savedData) {
            savedConfigs = decoded
        }
    }
    
    func saveRollConfig() {
        guard !newConfigName.isEmpty else { return }
        
        savedConfigs[newConfigName] = RollConfig(
            name: newConfigName,
            numberOfDice: numberOfDice,
            dieType: dice[dieSelector],
            modifier: modifier
        )
        
        saveConfigs()
        newConfigName = ""
    }
    
    func deleteConfig(at offsets: IndexSet) {
        for index in offsets {
            let keyToDelete = savedConfigs.keys.sorted()[index]
            savedConfigs.removeValue(forKey: keyToDelete)
        }
        saveConfigs()
    }
    
    var body: some View {
        VStack {
            Text("Diceroller")
                .font(.largeTitle)
                .multilineTextAlignment(.center)
                .padding(.bottom)
            Text("\(taglines[taglineIndex])").italic()
                .onAppear {
                    taglineIndex = Int.random(in: 0..<taglines.count)
                    startTaglineTimer()
                }
            Form {
                Section{
                    Stepper("\(numberOfDice)D\(dice[dieSelector])", value: $numberOfDice, in: 1...50)
                    Picker("Select a number", selection: $dieSelector) {
                        ForEach(dice.indices, id: \.self) { index in
                            Text("D\(dice[index])").tag(index)
                        }
                    }
                    .pickerStyle(SegmentedPickerStyle()) // Options: `MenuPickerStyle`, `SegmentedPickerStyle`, `WheelPickerStyle`
                }
                
                Section {
                    HStack {
                        Text("Modifier:")
                        Spacer()
                        Stepper("\(modifier >= 0 ? "+" : "")\(modifier)", value: $modifier)
                    }
                }
            }
            .frame(maxHeight: 220)

            Button("Roll", systemImage: "dice") {
                rolls = rollDice()
                result = rolls.map(\.self).reduce(0, +) + modifier
                print("Roll \(numberOfDice) D\(dice[dieSelector]) + \(modifier) = \(result)")
                
                if rolls.count > 10 {
                    let firstFew = rolls.prefix(5).map(\.description).joined(separator: " + ")
                    let lastFew = rolls.suffix(2).map((\.description)).joined(separator: " + ")
                    rollsText = "\(numberOfDice)D\(dice[dieSelector]) [\(firstFew) ... \(lastFew)] \(modifierText)"
                } else {
                    rollsText = "\(numberOfDice)D\(dice[dieSelector]) [" +
                    rolls.map(\.description).joined(separator: " + ")
                    + "]" + modifierText
                }
            }
            .buttonStyle(.borderedProminent)
            .padding()
            
            Text("\(rolls.isEmpty ? "" : "\(result)")")
                .font(.largeTitle)
                .fontWeight(.bold)
                .padding()
                .frame(maxWidth: .infinity, alignment: .center)
            Text("\(rollsText)")

            Spacer()
            
            Button("Saved Configs") {
                showingRollCollection = true
            }
            .buttonStyle(.borderedProminent)
            .sheet(isPresented: $showingRollCollection) {
                List {
                    ForEach(savedConfigs.keys.sorted(), id: \.self) {name in
                            Button(name) {
                                if let config = savedConfigs[name] {
                                    numberOfDice = config.numberOfDice
                                    dieSelector = dice.firstIndex(of: config.dieType) ?? 1
                                    modifier = config.modifier
                                }
                                showingRollCollection = false
                            }
                    }
                    .onDelete(perform: deleteConfig)
                }
            }
            .onAppear() {
                print ("loading")
                loadConfigs()
            }
            
            Button("Save Config") {
                showingSaveAlert = true // Show the name input popup
            }
            .buttonStyle(.borderedProminent)
            .alert("Save Roll Configuration", isPresented: $showingSaveAlert) {
                TextField("Enter name", text: $newConfigName)
                Button("Save", action: saveRollConfig) // Call function to save
                Button("Cancel", role: .cancel) { newConfigName = "" }
            } message: {
                Text("Enter a name for this roll.")
            }
            
            Button("Reset", role: .destructive) {
                reset()
            }
            .buttonStyle(.borderedProminent)

        }
        .padding()
    }
}

#Preview {
    ContentView()
}
