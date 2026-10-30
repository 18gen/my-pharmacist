//
//  MedicationMatcher.swift
//  MedLens
//

import Foundation

/// Matches the name read from a label (e.g. "METFORMIN HCL 500MG") to a registered medication.
nonisolated enum MedicationMatcher {
    /// Release-type words that make a different product ("Metformin ER" is not "Metformin").
    private static let formulationWords: Set<String> = ["er", "xr", "sr", "xl", "cr", "dr", "la", "cd", "odt"]

    private static let unitAliases: [String: String] = [
        "mg": "mg", "mcg": "mcg", "µg": "mcg", "ug": "mcg", "g": "g", "ml": "ml",
        "iu": "iu", "unit": "unit", "units": "unit", "%": "%",
    ]

    enum Result: Equatable {
        case match(Medication)
        case none
        case ambiguous
    }

    /// Requires every word of the registered name, the exact same strength, and no extra
    /// release-type word on the label.
    static func match(scannedName: String, in medications: [Medication]) -> Result {
        let scanned = tokens(scannedName)
        let scannedWords = Set(scanned)
        let scannedStrengths = strengths(in: scanned)
        guard !scannedStrengths.isEmpty else { return .none }

        let matches = medications.filter { medication in
            let nameTokens = tokens(medication.name)
            guard !nameTokens.isEmpty, nameTokens.allSatisfy(scannedWords.contains) else { return false }
            guard strengths(in: tokens(medication.strength)) == scannedStrengths else { return false }
            let extraFormulation = scannedWords.intersection(formulationWords).subtracting(nameTokens)
            return extraFormulation.isEmpty
        }

        switch matches.count {
        case 0: return .none
        case 1: return .match(matches[0])
        default: return .ambiguous
        }
    }

    /// Lowercased words and numbers, with "500mg" split into "500" "mg".
    static func tokens(_ text: String) -> [String] {
        var spaced = ""
        var previous: Character?
        for character in text.lowercased() {
            if let previous, previous.isNumber != character.isNumber,
               previous.isLetter || previous.isNumber, character.isLetter || character.isNumber {
                spaced.append(" ")
            }
            spaced.append(character)
            previous = character
        }
        return spaced
            .split { !($0.isLetter || $0.isNumber || $0 == "." || $0 == "%") }
            .map { String($0).trimmingCharacters(in: CharacterSet(charactersIn: ".")) }
            .filter { !$0.isEmpty }
    }

    /// Number + unit pairs, e.g. ["500 mg"], with numbers normalised ("500.0" → "500").
    static func strengths(in tokens: [String]) -> Set<String> {
        var result = Set<String>()
        for (index, token) in tokens.enumerated() where index + 1 < tokens.count {
            guard let value = Double(token), let unit = unitAliases[tokens[index + 1]] else { continue }
            let number = value.rounded() == value ? String(Int(value)) : String(value)
            result.insert("\(number) \(unit)")
        }
        return result
    }
}
