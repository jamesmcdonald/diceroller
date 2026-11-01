//
//  DiceExpressionControls.swift
//  Diceroller
//

import SwiftUI

/// Rows for entering a dice expression: a text field for typing notation like "2d6 + 1d4 + 3",
/// plus buttons that add dice, adjust the modifier, and set advantage without typing.
/// Used by both the quick roll section and the save/edit sheet.
struct DiceExpressionControls: View {
    @Binding var text: String

    /// The typed text if it's a complete roll, or why it isn't.
    private var validation: Result<DiceExpression, DiceExpressionError> {
        do {
            return .success(try DiceExpressionParser.parse(text))
        } catch let error as DiceExpressionError {
            return .failure(error)
        } catch {
            return .failure(.unexpected(text))
        }
    }

    /// What the buttons build on. This accepts incomplete rolls such as an empty field or just "+3",
    /// so the buttons only stop working when the text can't be understood at all.
    private var base: DiceExpression? {
        try? DiceExpressionParser.parse(text, allowingIncomplete: true)
    }

    private var advantage: Binding<DiceExpression.Advantage> {
        Binding {
            base?.advantage ?? .none
        } set: { newValue in
            update { expression in
                var expression = expression
                expression.advantage = newValue
                return expression
            }
        }
    }

    var body: some View {
        VStack(alignment: .leading, spacing: 4) {
            TextField("Roll, e.g. 2d6 + 1d4 + 3", text: $text)
                .font(.title3.monospaced())
                .autocorrectionDisabled()
                .textInputAutocapitalization(.never)
                .keyboardType(.asciiCapable)
                .submitLabel(.done)

            if !text.isEmpty, case .failure(let error) = validation {
                Text(error.localizedDescription)
                    .font(.footnote)
                    .foregroundStyle(.red)
            }
        }

        ScrollView(.horizontal) {
            HStack {
                ForEach(DieType.allCases, id: \.self) { die in
                    Button(die.description) {
                        update { $0.addingDie(sides: die.rawValue) }
                    }
                    .accessibilityLabel("Add a \(die.description)")
                }
            }
        }
        .scrollIndicators(.hidden)
        .buttonStyle(.bordered)
        .disabled(base == nil)

        HStack {
            Button("−1") {
                update { $0.addingModifier(-1) }
            }
            .accessibilityLabel("Subtract 1")
            Button("+1") {
                update { $0.addingModifier(1) }
            }
            .accessibilityLabel("Add 1")

            Spacer()

            Picker("Advantage", selection: advantage) {
                Text("Normal").tag(DiceExpression.Advantage.none)
                Text("Adv").tag(DiceExpression.Advantage.advantage)
                Text("Dis").tag(DiceExpression.Advantage.disadvantage)
            }
            .pickerStyle(.segmented)
            .fixedSize()
        }
        .buttonStyle(.bordered)
        .disabled(base == nil)
    }

    /// Applies an edit to the current expression and rewrites the text in canonical form.
    private func update(_ change: (DiceExpression) -> DiceExpression) {
        guard let base else { return }
        text = change(base).description
    }
}
