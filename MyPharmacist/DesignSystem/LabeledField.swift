//
//  LabeledField.swift
//  MyPharmacist
//

import SwiftUI

/// A field on a form: its label above, in small bold letters, and what is typed below it
/// in large ones.
struct LabeledField<Content: View>: View {
    let label: String
    let content: Content

    init(_ label: String, @ViewBuilder content: () -> Content) {
        self.label = label
        self.content = content()
    }

    var body: some View {
        VStack(alignment: .leading, spacing: 4) {
            Text(label)
                .font(.body.weight(.semibold))
                .foregroundStyle(Palette.textSecondary)
            content
                .font(.title3)
                .padding(.vertical, 6)
        }
    }
}

/// The text field of a `LabeledField` for plain words.
struct LabeledTextField: View {
    let label: String
    @Binding var text: String
    let prompt: String
    var capitalization: TextInputAutocapitalization = .sentences
    var autocorrects = true
    /// Vertical to wrap onto more lines as it is typed.
    var axis: Axis = .horizontal

    var body: some View {
        TextField(label, text: $text, prompt: Text(prompt), axis: axis)
            .lineLimit(1...4)
            .textInputAutocapitalization(capitalization)
            .autocorrectionDisabled(!autocorrects)
            .submitLabel(.done)
    }
}

extension LabeledField where Content == LabeledTextField {
    /// A labelled field for plain words.
    init(_ label: String, text: Binding<String>, prompt: String, capitalization: TextInputAutocapitalization = .sentences,
         autocorrects: Bool = true, axis: Axis = .horizontal) {
        self.init(label) {
            LabeledTextField(label: label, text: text, prompt: prompt, capitalization: capitalization,
                             autocorrects: autocorrects, axis: axis)
        }
    }
}
