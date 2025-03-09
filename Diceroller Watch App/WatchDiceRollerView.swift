//
//  ContentView.swift
//  Diceroller Watch Watch App
//
//  Created by James McDonald on 08/03/2025.
//

import SwiftUI

struct WatchDiceRollerView: View {
    @State private var numberOfDice: Int = 1
    @State private var selectedDie: Int = 6
    @State private var modifier: Int = 0
    @State private var result: Int = 0
    @State private var showingConfigSheet: Bool = false
    @State private var showingSavedRolls: Bool = false

    let diceOptions = [4, 6, 8, 10, 12, 20, 100]

    var modifierText: String {
        modifier == 0 ? "" : (modifier > 0 ? "+" : "") + "\(modifier)"
    }
    var body: some View {
        VStack {
            HStack {
                Button("\(numberOfDice)D\(selectedDie)\(modifierText)") {
                    showingConfigSheet = true
                }
                
                Button("🎲") {
                    result = (1...numberOfDice).map { _ in Int.random(in: 1...selectedDie) }.reduce(0, +) + modifier
                    WKInterfaceDevice.current().play(.success)
                }
            }
            Button("Saved") {
                showingSavedRolls = true
            }
            .padding()
            
            .sheet(isPresented: $showingSavedRolls) {
                List(WatchSyncManager.shared.savedConfigs.keys.sorted(), id: \.self) { name in
                    Button(name) {
                        if let config = WatchSyncManager.shared.savedConfigs[name] {
                            numberOfDice = config.numberOfDice
                            selectedDie = config.dieType
                            modifier = config.modifier
                        }
                        showingSavedRolls = false
                    }
                }
            }


            Text("Result: \(result)")
            .font(.title)
        }
        .sheet(isPresented: $showingConfigSheet) {
            DiceConfigView(
                numberOfDice: $numberOfDice,
                selectedDie: $selectedDie,
                modifier: $modifier,
                diceOptions: diceOptions,
                dismiss: { showingConfigSheet = false }
            )
        }
    }
}

struct DiceConfigView: View {
    @Binding var numberOfDice: Int
    @Binding var selectedDie: Int
    @Binding var modifier: Int
    let diceOptions: [Int]
    let dismiss: () -> Void

    @State private var showingDicePicker = false
    @State private var showingDiePicker = false
    @State private var showingModifierPicker = false

    var body: some View {
        List {
            // Number of Dice (Tappable Row)
            Button(action: { showingDicePicker = true }) {
                HStack {
                    Text("Number of Dice")
                    Spacer()
                    Text("\(numberOfDice)").foregroundColor(.gray)
                }
            }
            .sheet(isPresented: $showingDicePicker) {
                SelectionView(
                    title: "Select Number of Dice",
                    options: Array(1...10).map { "\($0)" },
                    selected: "\(numberOfDice)",
                    onSelect: { numberOfDice = Int($0) ?? 1 }
                )
            }

            // Die Type (Tappable Row)
            Button(action: { showingDiePicker = true }) {
                HStack {
                    Text("Die Type")
                    Spacer()
                    Text("D\(selectedDie)").foregroundColor(.gray)
                }
            }
            .sheet(isPresented: $showingDiePicker) {
                SelectionView(
                    title: "Select Die Type",
                    options: diceOptions.map { "D\($0)" },
                    selected: "D\(selectedDie)",
                    onSelect: { selectedDie = Int($0.dropFirst()) ?? 6 }
                )
            }

            // Modifier (Tappable Row)
            Button(action: { showingModifierPicker = true }) {
                HStack {
                    Text("Modifier")
                    Spacer()
                    Text("\(modifier >= 0 ? "+" : "")\(modifier)").foregroundColor(.gray)
                }
            }
            .sheet(isPresented: $showingModifierPicker) {
                SelectionView(
                    title: "Select Modifier",
                    options: Array(-10...10).map { "\($0 >= 0 ? "+" : "")\($0)" },
                    selected: "\(modifier >= 0 ? "+" : "")\(modifier)",
                    onSelect: { modifier = Int($0) ?? 0 }
                )
            }

            Button("Done") { dismiss() }
                .padding()
        }
    }
}

// 🔥 Reusable Selection Sheet
struct SelectionView: View {
    let title: String
    let options: [String]
    let selected: String
    var onSelect: (String) -> Void
    @Environment(\.dismiss) private var dismiss

    var body: some View {
        List {
            Text(title).font(.headline)
            ForEach(options, id: \.self) { option in
                Button(action: {
                    onSelect(option)
                    dismiss()
                }) {
                    HStack {
                        Text(option)
                        Spacer()
                        if option == selected { Image(systemName: "checkmark") }
                    }
                }
            }
        }
    }
}

#Preview {
    WatchDiceRollerView()
}
