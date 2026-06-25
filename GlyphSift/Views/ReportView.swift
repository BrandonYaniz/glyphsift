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
        WrappingFlowLayout(spacing: 6) {
            ForEach(items) { item in
                content(item)
            }
        }
    }
}

private struct WrappingFlowLayout: Layout {
    var spacing: CGFloat

    func sizeThatFits(proposal: ProposedViewSize, subviews: Subviews, cache: inout ()) -> CGSize {
        let rows = makeRows(proposal: proposal, subviews: subviews)
        return CGSize(
            width: proposal.width ?? rows.map(\.width).max() ?? 0,
            height: rows.reduce(0) { $0 + $1.height } + spacing * CGFloat(max(rows.count - 1, 0))
        )
    }

    func placeSubviews(in bounds: CGRect, proposal: ProposedViewSize, subviews: Subviews, cache: inout ()) {
        var y = bounds.minY
        for row in makeRows(proposal: ProposedViewSize(width: bounds.width, height: nil), subviews: subviews) {
            var x = bounds.minX
            for item in row.items {
                subviews[item.index].place(
                    at: CGPoint(x: x, y: y),
                    proposal: ProposedViewSize(item.size)
                )
                x += item.size.width + spacing
            }
            y += row.height + spacing
        }
    }

    private func makeRows(proposal: ProposedViewSize, subviews: Subviews) -> [Row] {
        let maxWidth = proposal.width ?? .greatestFiniteMagnitude
        var rows: [Row] = []
        var currentItems: [RowItem] = []
        var currentWidth: CGFloat = 0
        var currentHeight: CGFloat = 0

        for index in subviews.indices {
            let size = subviews[index].sizeThatFits(.unspecified)
            let nextWidth = currentItems.isEmpty ? size.width : currentWidth + spacing + size.width
            if nextWidth > maxWidth, !currentItems.isEmpty {
                rows.append(Row(items: currentItems, width: currentWidth, height: currentHeight))
                currentItems = [RowItem(index: index, size: size)]
                currentWidth = size.width
                currentHeight = size.height
            } else {
                currentItems.append(RowItem(index: index, size: size))
                currentWidth = nextWidth
                currentHeight = max(currentHeight, size.height)
            }
        }

        if !currentItems.isEmpty {
            rows.append(Row(items: currentItems, width: currentWidth, height: currentHeight))
        }
        return rows
    }

    private struct Row {
        var items: [RowItem]
        var width: CGFloat
        var height: CGFloat
    }

    private struct RowItem {
        var index: Int
        var size: CGSize
    }
}
