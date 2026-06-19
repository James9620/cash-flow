//
//  AppIntent.swift
//  CashFlowWidgets
//
//  Created by James Larkin on 6/18/26.
//

import WidgetKit
import AppIntents

enum CashFlowWidgetDisplay: String, AppEnum {
    case discretionaryNumber
    case progressBar
    case billStack

    static var typeDisplayRepresentation: TypeDisplayRepresentation {
        "Widget Type"
    }

    static var caseDisplayRepresentations: [CashFlowWidgetDisplay: DisplayRepresentation] {
        [
            .discretionaryNumber: "Discretionary Number",
            .progressBar: "Progress Bar",
            .billStack: "Bill Stack"
        ]
    }
}

struct ConfigurationAppIntent: WidgetConfigurationIntent {
    static var title: LocalizedStringResource { "Cash Flow Widget" }
    static var description: IntentDescription { "Choose which Cash Flow widget to show." }

    // This lets one widget extension render all three Cash Flow widget styles.
    @Parameter(title: "Widget Type", default: .discretionaryNumber)
    var display: CashFlowWidgetDisplay
}
