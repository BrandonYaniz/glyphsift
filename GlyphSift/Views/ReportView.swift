import SwiftUI

struct ReportView: View {
    let result: CleaningResult
    let rules: [RegexRule]

    var body: some View {
        VStack(alignment: .leading, spacing: 10) {
            Text("Report")
                .font(.headline)

            if result.original.isEmpty {
                Text("Select or paste text to see what GlyphSift finds.")
                    .foregroundStyle(.secondary)
            } else if result.findings.isEmpty {
                Text("No issues found for this preset.")
                    .foregroundStyle(.secondary)
            } else {
                summaryGrid
                categoryCounts
                regexCounts
            }
        }
        .padding(12)
        .frame(maxWidth: .infinity, alignment: .leading)
        .background(.regularMaterial)
        .clipShape(RoundedRectangle(cornerRadius: 12))
    }

    private var summaryGrid: some View {
        Grid(alignment: .leading, horizontalSpacing: 24, verticalSpacing: 6) {
            GridRow {
                label("Preset")
                value(result.report.presetName)
                label("Total findings")
                value("\(result.report.totalFindings)")
                label("Changes")
                value("\(result.report.totalChanges)")
            }
            GridRow {
                label("Characters")
                value("\(result.report.charactersBefore) → \(result.report.charactersAfter)")
                label("Words")
                value("\(result.report.wordsBefore) → \(result.report.wordsAfter)")
                label("Output")
                value(result.cleaned.isEmpty ? "Empty" : "Ready")
            }
        }
        .font(.callout)
    }

    private var categoryCounts: some View {
        VStack(alignment: .leading, spacing: 4) {
            Text("Category Counts")
                .font(.subheadline.weight(.semibold))
            FlowLayout(items: FindingCategory.allCases.filter { (result.report.categoryCounts[$0] ?? 0) > 0 }) { category in
                Text("\(category.displayName): \(result.report.categoryCounts[category] ?? 0)")
                    .font(.caption)
                    .padding(.horizontal, 8)
                    .padding(.vertical, 4)
                    .background(.thinMaterial)
                    .clipShape(Capsule())
            }
        }
    }

    @ViewBuilder
    private var regexCounts: some View {
        let counts = result.report.ruleCounts
        if !counts.isEmpty {
            VStack(alignment: .leading, spacing: 4) {
                Text("Regex Rule Counts")
                    .font(.subheadline.weight(.semibold))
                ForEach(rules.sorted { $0.order < $1.order }) { rule in
                    if let count = counts[rule.id] {
                        Text("\(rule.name): \(count)")
                            .font(.caption)
                    }
                }
            }
        }
    }

    private func label(_ text: String) -> some View {
        Text(text)
            .foregroundStyle(.secondary)
    }

    private func value(_ text: String) -> some View {
        Text(text)
            .fontWeight(.medium)
    }
}

private struct FlowLayout<Item: Identifiable, Content: View>: View {
    let items: [Item]
    let content: (Item) -> Content

    var body: some View {
        HStack {
            ForEach(items) { item in
                content(item)
            }
        }
    }
}
