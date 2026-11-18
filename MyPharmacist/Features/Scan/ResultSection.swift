//
//  ResultSection.swift
//  MyPharmacist
//

import SwiftUI

/// One level's heading and its rows.
struct ResultSection: View {
    let group: ResultGroup
    let pharmacyCall: URL?
    @Binding var highlighted: Int?

    var body: some View {
        VStack(alignment: .leading, spacing: 10) {
            Label(group.level.title, systemImage: group.level.icon)
                .font(.title3.bold())
                .foregroundStyle(group.level.color)
                .accessibilityAddTraits(.isHeader)
            ForEach(group.lines) { line in
                if case .pill(let pill) = line {
                    ResultRow(line: line, isHighlighted: highlighted == pill.id,
                              detail: pill.detail(pharmacyCall: pharmacyCall)) {
                        withAnimation(.easeInOut(duration: 0.2)) {
                            highlighted = highlighted == pill.id ? nil : pill.id
                        }
                    }
                    .id(line.id)
                } else {
                    ResultRow(line: line)
                }
            }
        }
    }
}
