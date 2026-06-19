//
//  CashFlowWidgetsBundle.swift
//  CashFlowWidgets
//
//  Created by James Larkin on 6/18/26.
//

import WidgetKit
import SwiftUI

@main
struct CashFlowWidgetsBundle: WidgetBundle {
    var body: some Widget {
        CashFlowWidgets()
        CashFlowWidgetsControl()
        CashFlowWidgetsLiveActivity()
    }
}
