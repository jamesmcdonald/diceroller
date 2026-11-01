//
//  ContentView.swift
//  Diceroller
//
//  Created by James McDonald on 08/03/2025.
//

import SwiftUI

struct ContentView: View {
    @Environment(RollStore.self) private var store

    @State private var quickRoll = ContentView.defaultQuickRoll
    @State private var lastRoll: LastRoll?
    @State private var editorRequest: EditorRequest?
    @State private var taglineIndex: Int = 0

    private static let defaultQuickRoll = RollConfig(name: "", numberOfDice: 1, dieType: .defaultDie, modifier: 0)

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

    var body: some View {
        NavigationStack {
            List {
                Section {
                    RollConfigControls(config: $quickRoll)

                    Button {
                        roll(quickRoll, title: "Quick Roll")
                    } label: {
                        Label("Roll \(quickRoll.notation)", systemImage: "dice")
                            .frame(maxWidth: .infinity)
                    }
                    .buttonStyle(.borderedProminent)
                    .listRowInsets(EdgeInsets(top: 8, leading: 16, bottom: 8, trailing: 16))
                } header: {
                    HStack {
                        Text("Quick Roll")
                        Spacer()
                        Button("Reset", action: reset)
                            .font(.footnote)
                            .textCase(nil)
                    }
                } footer: {
                    Text(taglines[taglineIndex])
                        .italic()
                        .task {
                            // Pick a new tagline now and every 5 minutes; the loop ends when the view disappears.
                            repeat {
                                taglineIndex = Int.random(in: 0..<taglines.count)
                            } while (try? await Task.sleep(for: .seconds(300))) != nil
                        }
                }

                Section("Saved Rolls") {
                    if store.configs.isEmpty {
                        Text("Tap + to save the quick roll, then roll it again here with one tap.")
                            .foregroundStyle(.secondary)
                    }

                    ForEach(store.configs) { config in
                        SavedRollRow(config: config) {
                            roll(config, title: config.name)
                        }
                        .swipeActions(edge: .trailing) {
                            Button("Delete", systemImage: "trash", role: .destructive) {
                                store.delete(ids: [config.id])
                            }
                            Button("Edit", systemImage: "pencil") {
                                editorRequest = EditorRequest(config: config, isNew: false)
                            }
                        }
                        .swipeActions(edge: .leading) {
                            Button("Duplicate", systemImage: "plus.square.on.square") {
                                store.duplicate(config)
                            }
                            .tint(.indigo)
                        }
                        .contextMenu {
                            Button("Edit", systemImage: "pencil") {
                                editorRequest = EditorRequest(config: config, isNew: false)
                            }
                            Button("Duplicate", systemImage: "plus.square.on.square") {
                                store.duplicate(config)
                            }
                            Button("Delete", systemImage: "trash", role: .destructive) {
                                store.delete(ids: [config.id])
                            }
                        }
                    }
                    .onMove(perform: store.move)
                    .onDelete { offsets in
                        store.delete(ids: Set(offsets.map { store.configs[$0].id }))
                    }
                }
            }
            .navigationTitle("Diceroller")
            .toolbar {
                ToolbarItem(placement: .topBarLeading) {
                    EditButton()
                        .disabled(store.configs.isEmpty)
                }
                ToolbarItem(placement: .primaryAction) {
                    Button("Save Quick Roll", systemImage: "plus") {
                        editorRequest = EditorRequest(config: RollConfig(
                            name: "",
                            numberOfDice: quickRoll.numberOfDice,
                            dieType: quickRoll.dieType,
                            modifier: quickRoll.modifier
                        ), isNew: true)
                    }
                }
            }
            .safeAreaInset(edge: .bottom) {
                if let lastRoll {
                    RollResultBanner(lastRoll: lastRoll) {
                        roll(lastRoll.config, title: lastRoll.title)
                    }
                    .transition(.move(edge: .bottom).combined(with: .opacity))
                }
            }
            .sheet(item: $editorRequest) { request in
                RollConfigEditor(request: request)
            }
        }
    }

    private func roll(_ config: RollConfig, title: String) {
        withAnimation(.snappy) {
            lastRoll = LastRoll(title: title, config: config, result: config.roll())
        }
    }

    private func reset() {
        withAnimation(.snappy) {
            quickRoll = Self.defaultQuickRoll
            lastRoll = nil
        }
    }
}

/// A saved roll in the list. Tapping it rolls immediately.
struct SavedRollRow: View {
    let config: RollConfig
    let roll: () -> Void

    var body: some View {
        Button(action: roll) {
            HStack {
                VStack(alignment: .leading) {
                    Text(config.name)
                        .font(.headline)
                    Text(config.notation)
                        .font(.subheadline)
                        .foregroundStyle(.secondary)
                }
                Spacer()
                Image(systemName: "dice")
                    .foregroundStyle(.tint)
            }
            .contentShape(.rect)
        }
        .foregroundStyle(.primary)
        .accessibilityHint("Rolls \(config.notation)")
    }
}

#Preview {
    ContentView()
        .environment(RollStore.preview())
}
