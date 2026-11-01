//
//  ContentView.swift
//  Diceroller
//
//  Created by James McDonald on 08/03/2025.
//

import SwiftUI

struct ContentView: View {
    @Environment(RollStore.self) private var store

    // Main form state
    @State private var taglineIndex: Int = 0
    
    @State private var numberOfDice: Int = 1;
    @State private var dieType: DieType = DieType.defaultDie;
    @State private var modifier: Int = 0;
    
    @State private var lastRoll: RollResult?
    
    // Save form state
    @State private var newConfigName = ""

    // Form toggles
    @State private var showingRollCollection: Bool = false;
    @State private var showingSaveAlert = false
    
    private let taglines: [String] = [
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
    
    var modifierText: String {
        if modifier == 0 {
            return ""
        }
        return modifier > 0 ? " + \(modifier)" : " - \(abs(modifier))"
    }
    
    func reset() {
        numberOfDice = 1
        dieType = DieType.defaultDie
        modifier = 0
        lastRoll = nil
    }
    
    func saveRollConfig() {
        guard !newConfigName.isEmpty else { return }
        
        store.save(RollConfig(
            name: newConfigName,
            numberOfDice: numberOfDice,
            dieType: dieType,
            modifier: modifier
        ))
        
        newConfigName = ""
    }
    
    func deleteConfig(at offsets: IndexSet) {
        let names = store.sortedNames
        store.delete(names: offsets.map { names[$0] })
    }
    
    func natColor(for roll: RollResult) -> Color {
        if roll.isNaturalOne { return .red }
        if roll.isNaturalMax { return .green }
        return .primary
    }

    func natText(for roll: RollResult) -> String {
        if let nat = roll.natural, roll.dieType == .d20, roll.isNaturalOne || roll.isNaturalMax {
            return "Nat \(nat) (\(roll.total))"
        }
        return "\(roll.total)"
    }

    /// Describes the individual dice, abbreviating long lists of rolls.
    func rollsText(for roll: RollResult) -> String {
        let dice = "\(roll.rolls.count)\(roll.dieType.description)"
        let rollModifierText = roll.modifier == 0 ? "" : (roll.modifier > 0 ? " + \(roll.modifier)" : " - \(abs(roll.modifier))")
        if roll.rolls.count > 10 {
            let firstFew = roll.rolls.prefix(5).map(\.description).joined(separator: " + ")
            let lastFew = roll.rolls.suffix(2).map(\.description).joined(separator: " + ")
            return "\(dice) [\(firstFew) ... \(lastFew)]\(rollModifierText)"
        }
        return "\(dice) [" + roll.rolls.map(\.description).joined(separator: " + ") + "]" + rollModifierText
    }
    
    var body: some View {
        VStack {
            Text("Diceroller")
                .font(.largeTitle)
                .multilineTextAlignment(.center)
                .padding(.bottom)
            Text("\(taglines[taglineIndex])").italic()
                .task {
                    // Pick a new tagline now and every 5 minutes; the loop ends when the view disappears.
                    repeat {
                        taglineIndex = Int.random(in: 0..<taglines.count)
                    } while (try? await Task.sleep(for: .seconds(300))) != nil
                }
            Form {
                Section{
                    Stepper("\(numberOfDice)\(dieType.description)", value: $numberOfDice, in: RollConfig.numberOfDiceRange)
                    Picker("Select a number", selection: $dieType) {
                        ForEach(DieType.allCases, id: \.self) { die in
                            Text("\(die.description)").tag(die)
                        }
                    }
                    .pickerStyle(SegmentedPickerStyle()) // Options: `MenuPickerStyle`, `SegmentedPickerStyle`, `WheelPickerStyle`
                }
                
                Section {
                    HStack {
                        Text("Modifier:")
                        Spacer()
                        Stepper("\(modifier > 0 ? "+" : "")\(modifier)", value: $modifier, in: RollConfig.modifierRange)
                    }
                }
            }
            .frame(maxHeight: 220)

            Button("Roll \(numberOfDice)\(dieType.description)\(modifierText)", systemImage: "dice") {
                lastRoll = RollConfig(
                    name: "",
                    numberOfDice: numberOfDice,
                    dieType: dieType,
                    modifier: modifier).roll()
            }
            .buttonStyle(.borderedProminent)
            .padding()
                        
            if let lastRoll {
                Text(natText(for: lastRoll))
                    .font(.largeTitle)
                    .fontWeight(.bold)
                    .foregroundColor(natColor(for: lastRoll))
                Text(rollsText(for: lastRoll))
            }

            Spacer()
            
            Button("Saved Configs") {
                showingRollCollection = true
            }
            .buttonStyle(.borderedProminent)
            .sheet(isPresented: $showingRollCollection) {
                List {
                    ForEach(store.sortedNames, id: \.self) {name in
                            Button(name) {
                                if let config = store.savedConfigs[name] {
                                    numberOfDice = config.numberOfDice
                                    dieType = config.dieType
                                    modifier = config.modifier
                                }
                                showingRollCollection = false
                            }
                    }
                    .onDelete(perform: deleteConfig)
                }
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
        .environment(RollStore())
}
