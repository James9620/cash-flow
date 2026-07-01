//
//  CashFlowTheme.swift
//  cash-flow
//
//  Created by Codex on 7/1/26.
//

import SwiftUI

enum CashFlowTheme {
    static let background = Color(red: 10 / 255, green: 10 / 255, blue: 15 / 255)
    static let surface = Color(red: 26 / 255, green: 26 / 255, blue: 36 / 255)
    static let elevatedSurface = Color(red: 33 / 255, green: 33 / 255, blue: 45 / 255)
    static let track = Color(red: 42 / 255, green: 42 / 255, blue: 56 / 255)
    static let accent = Color(red: 74 / 255, green: 158 / 255, blue: 255 / 255)
    static let success = Color(red: 0 / 255, green: 212 / 255, blue: 184 / 255)
    static let warning = Color(red: 255 / 255, green: 197 / 255, blue: 92 / 255)
    static let error = Color(red: 255 / 255, green: 95 / 255, blue: 116 / 255)
    static let primaryText = Color.white
    static let secondaryText = Color(red: 158 / 255, green: 163 / 255, blue: 176 / 255)
    static let hairline = Color.white.opacity(0.08)

    static let cornerRadius: CGFloat = 8
    static let panelPadding: CGFloat = 18
}

struct CashFlowPanel<Content: View>: View {
    let content: Content

    init(@ViewBuilder content: () -> Content) {
        self.content = content()
    }

    var body: some View {
        content
            .padding(CashFlowTheme.panelPadding)
            .frame(maxWidth: .infinity, alignment: .leading)
            .background(CashFlowTheme.surface)
            .clipShape(RoundedRectangle(cornerRadius: CashFlowTheme.cornerRadius))
            .overlay {
                RoundedRectangle(cornerRadius: CashFlowTheme.cornerRadius)
                    .stroke(CashFlowTheme.hairline, lineWidth: 1)
            }
            .shadow(color: .black.opacity(0.22), radius: 14, x: 0, y: 10)
    }
}

struct CashFlowStatusPill: View {
    let title: String
    let color: Color
    let systemImage: String?

    init(_ title: String, color: Color, systemImage: String? = nil) {
        self.title = title
        self.color = color
        self.systemImage = systemImage
    }

    var body: some View {
        HStack(spacing: 6) {
            if let systemImage {
                Image(systemName: systemImage)
                    .font(.caption2.weight(.black))
            }

            Text(title)
                .font(.caption.weight(.black))
        }
        .foregroundStyle(color)
        .padding(.horizontal, 10)
        .padding(.vertical, 6)
        .background(color.opacity(0.14))
        .clipShape(Capsule())
    }
}

struct CashFlowPercentageField: View {
    let title: String
    let caption: String
    @Binding var text: String

    var body: some View {
        VStack(alignment: .leading, spacing: 8) {
            Text(title)
                .font(.caption.weight(.bold))
                .foregroundStyle(CashFlowTheme.secondaryText)

            HStack(spacing: 10) {
                TextField(title, text: $text)
                    .keyboardType(.decimalPad)
                    .textInputAutocapitalization(.never)
                    .autocorrectionDisabled()
                    .font(.title3.weight(.bold))
                    .foregroundStyle(CashFlowTheme.primaryText)

                Text("%")
                    .font(.headline.weight(.black))
                    .foregroundStyle(CashFlowTheme.accent)
            }
            .padding(.horizontal, 14)
            .padding(.vertical, 12)
            .background(CashFlowTheme.elevatedSurface)
            .clipShape(RoundedRectangle(cornerRadius: CashFlowTheme.cornerRadius))
            .overlay {
                RoundedRectangle(cornerRadius: CashFlowTheme.cornerRadius)
                    .stroke(CashFlowTheme.hairline, lineWidth: 1)
            }

            Text(caption)
                .font(.caption)
                .foregroundStyle(CashFlowTheme.secondaryText)
                .fixedSize(horizontal: false, vertical: true)
        }
    }
}

struct CashFlowAllocationBar: View {
    let savingsPercentage: Double
    let billsReservePercentage: Double
    let isPro: Bool

    private var split: IncomeSplit {
        IncomeSplit(
            savingsPercentage: savingsPercentage,
            billsReservePercentage: billsReservePercentage,
            subscriptionStatus: isPro ? .pro : .free
        )
    }

    var body: some View {
        VStack(alignment: .leading, spacing: 10) {
            GeometryReader { proxy in
                HStack(spacing: 3) {
                    ForEach(segments) { segment in
                        RoundedRectangle(cornerRadius: 3)
                            .fill(segment.color)
                            .frame(width: max(proxy.size.width * segment.fraction, segment.fraction > 0 ? 4 : 0))
                    }
                }
            }
            .frame(height: 9)

            HStack(spacing: 10) {
                ForEach(segments.filter { $0.percentage > 0 }) { segment in
                    HStack(spacing: 5) {
                        Circle()
                            .fill(segment.color)
                            .frame(width: 6, height: 6)

                        Text("\(segment.label) \(formattedPercent(segment.percentage))")
                            .font(.caption2.weight(.bold))
                            .foregroundStyle(CashFlowTheme.secondaryText)
                            .lineLimit(1)
                            .minimumScaleFactor(0.75)
                    }
                }
            }
        }
    }

    private var segments: [CashFlowAllocationSegment] {
        [
            CashFlowAllocationSegment(label: "Save", percentage: split.effectiveSavingsPercentage, color: CashFlowTheme.accent),
            CashFlowAllocationSegment(label: "Bills", percentage: split.effectiveBillsReservePercentage, color: CashFlowTheme.warning),
            CashFlowAllocationSegment(label: "Spend", percentage: split.discretionaryPercentage, color: CashFlowTheme.success)
        ]
    }

    private func formattedPercent(_ value: Double) -> String {
        let rounded = value.rounded()
        if abs(value - rounded) < 0.001 {
            return "\(Int(rounded))%"
        }

        return "\(String(format: "%.1f", value))%"
    }
}

private struct CashFlowAllocationSegment: Identifiable {
    let id = UUID()
    let label: String
    let percentage: Double
    let color: Color

    var fraction: Double {
        max(percentage, 0) / 100
    }
}

struct CashFlowMiniWidgetPreview: View {
    let balance: Double
    let statusText: String

    var body: some View {
        VStack(alignment: .leading, spacing: 8) {
            HStack {
                Text("Discretionary")
                    .font(.caption.weight(.bold))
                    .foregroundStyle(CashFlowTheme.primaryText)
                    .lineLimit(1)

                Spacer()

                Text(statusText)
                    .font(.caption2.weight(.bold))
                    .foregroundStyle(CashFlowTheme.secondaryText)
                    .lineLimit(1)
            }

            Spacer(minLength: 0)

            Text(balance, format: .currency(code: "USD"))
                .font(.system(size: 36, weight: .black, design: .rounded))
                .foregroundStyle(CashFlowTheme.primaryText)
                .minimumScaleFactor(0.58)
                .lineLimit(1)

            Text("Available now")
                .font(.caption.weight(.semibold))
                .foregroundStyle(CashFlowTheme.secondaryText)
        }
        .padding(14)
        .frame(width: 172, height: 172, alignment: .leading)
        .background(CashFlowTheme.background)
        .clipShape(RoundedRectangle(cornerRadius: CashFlowTheme.cornerRadius))
        .overlay {
            RoundedRectangle(cornerRadius: CashFlowTheme.cornerRadius)
                .stroke(CashFlowTheme.hairline, lineWidth: 1)
        }
    }
}
