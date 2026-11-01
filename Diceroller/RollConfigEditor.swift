//
//  RollConfigEditor.swift
//  Diceroller
//

import SwiftUI

/// A request to show the editor, either to save a new roll or edit an existing one.
struct EditorRequest: Identifiable {
    var config: RollConfig
    let isNew: Bool

    var id: RollConfig.ID { config.id }
}

/// A sheet for naming a new saved roll, or changing an existing one.
struct RollConfigEditor: View {
    @Environment(RollStore.self) private var store
    @Environment(\.dismiss) private var dismiss

    @State private var config: RollConfig
    @State private var expressionText: String
    @FocusState private var isNameFocused: Bool
    private let isNew: Bool

    init(request: EditorRequest) {
        _config = State(initialValue: request.config)
        _expressionText = State(initialValue: request.config.notation)
        isNew = request.isNew
    }

    private var trimmedName: String {
        config.name.trimmingCharacters(in: .whitespacesAndNewlines)
    }

    private var isNameTaken: Bool {
        store.isNameTaken(trimmedName, excluding: config.id)
    }

    private var expression: DiceExpression? {
        try? DiceExpressionParser.parse(expressionText)
    }

    private var canSave: Bool {
        !trimmedName.isEmpty && !isNameTaken && expression != nil
    }

    var body: some View {
        NavigationStack {
            Form {
                Section {
                    TextField("Name, e.g. Attack", text: $config.name)
                        .focused($isNameFocused)
                        .submitLabel(.done)
                        .onSubmit(save)
                } footer: {
                    if isNameTaken {
                        Text("You already have a roll called “\(trimmedName)”.")
                            .foregroundStyle(.red)
                    }
                }

                Section {
                    DiceExpressionControls(text: $expressionText)
                } footer: {
                    Text("Combine dice like 2d6 + 1d4 + 3. Use dl1 to drop the lowest die (4d6dl1), kh1 to keep the highest (2d20kh1), and (adv) or (dis) for a d20 roll.")
                }
            }
            .navigationTitle(isNew ? "Save Roll" : "Edit Roll")
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .cancellationAction) {
                    Button("Cancel") { dismiss() }
                }
                ToolbarItem(placement: .confirmationAction) {
                    Button("Save", action: save)
                        .disabled(!canSave)
                }
            }
            .onAppear {
                // Jump straight to naming when saving a new roll.
                isNameFocused = isNew
            }
        }
        .presentationDetents([.medium, .large])
    }

    private func save() {
        guard canSave, let expression else { return }
        config.name = trimmedName
        config.expression = expression
        if isNew {
            store.add(config)
        } else {
            store.update(config)
        }
        dismiss()
    }
}

#Preview {
    RollConfigEditor(request: EditorRequest(
        config: RollConfig(name: "", expression: .simple(count: 1, sides: 20, modifier: 5)),
        isNew: true
    ))
    .environment(RollStore.preview())
}
