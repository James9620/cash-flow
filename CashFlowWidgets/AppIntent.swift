//
//  AppIntent.swift
//  CashFlowWidgets
//
//  Created by James Larkin on 6/18/26.
//

import WidgetKit
import AppIntents

enum CashFlowWidgetDisplay: Equatable {
    case discretionaryNumber
    case progressBar
    case billStack
}

struct ConfigurationAppIntent: WidgetConfigurationIntent {
    static var title: LocalizedStringResource { "Discretionary Number" }
    static var description: IntentDescription { "Shows your latest discretionary spending snapshot." }
}
