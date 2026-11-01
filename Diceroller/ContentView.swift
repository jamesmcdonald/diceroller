//
//  ContentView.swift
//  Diceroller
//
//  Created by James McDonald on 08/03/2025.
//

import SwiftUI

struct ContentView: View {
    @Environment(RollStore.self) private var store

    @State private var quickRollText = ContentView.defaultQuickRoll
    @State private var lastRoll: LastRoll?
    @State private var editorRequest: EditorRequest?
    @State private var taglineIndex: Int = 0

    private static let defaultQuickRoll = DiceExpression.simple(count: 1, sides: DieType.defaultDie.rawValue, modifier: 0).description

    /// The quick roll, if the text is a complete roll.
    private var quickExpression: DiceExpression? {
        try? DiceExpressionParser.parse(quickRollText)
    }

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
                    DiceExpressionControls(text: $quickRollText)

                    Button {
                        if let quickExpression {
                            roll(RollConfig(name: "", expression: quickExpression), title: "Quick Roll")
                        }
                    } label: {
                        Label(quickExpression.map { "Roll \($0)" } ?? "Roll", systemImage: "dice")
                            .lineLimit(1)
                            .frame(maxWidth: .infinity)
                    }
                    .buttonStyle(.borderedProminent)
                    .disabled(quickExpression == nil)
                    .listRowInsets(EdgeInsets(top: 8, leading: 16, bottom: 8, trailing: 16))
                } header: {
                    HStack {
                        Text("Quick Roll")
                        Spacer()
                        Button("Reset", action: reset)
                            .font(.footnote)
                            .textCase(nil)
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
            // The title isn't shown, but VoiceOver and the app switcher still use it.
            .navigationTitle("Diceroller")
            .navigationBarTitleDisplayMode(.inline)
            .task {
                // Pick a new tagline now and every 5 minutes; the loop ends when the view disappears.
                repeat {
                    taglineIndex = Int.random(in: 0..<taglines.count)
                } while (try? await Task.sleep(for: .seconds(300))) != nil
            }
            .toolbar {
                ToolbarItem(placement: .principal) {
                    Text(taglines[taglineIndex])
                        .font(.subheadline)
                        .italic()
                        .foregroundStyle(.secondary)
                        .lineLimit(1)
                        .minimumScaleFactor(0.8)
                }
                ToolbarItem(placement: .topBarLeading) {
                    EditButton()
                        .disabled(store.configs.isEmpty)
                }
                ToolbarItem(placement: .primaryAction) {
                    Button("Save Quick Roll", systemImage: "plus") {
                        if let quickExpression {
                            editorRequest = EditorRequest(config: RollConfig(name: "", expression: quickExpression), isNew: true)
                        }
                    }
                    .disabled(quickExpression == nil)
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
            quickRollText = Self.defaultQuickRoll
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
