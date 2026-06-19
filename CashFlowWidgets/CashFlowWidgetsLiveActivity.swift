//
//  CashFlowWidgetsLiveActivity.swift
//  CashFlowWidgets
//
//  Created by James Larkin on 6/18/26.
//

import ActivityKit
import WidgetKit
import SwiftUI

struct CashFlowWidgetsAttributes: ActivityAttributes {
    public struct ContentState: Codable, Hashable {
        // Dynamic stateful properties about your activity go here!
        var emoji: String
    }

    // Fixed non-changing properties about your activity go here!
    var name: String
}

struct CashFlowWidgetsLiveActivity: Widget {
    var body: some WidgetConfiguration {
        ActivityConfiguration(for: CashFlowWidgetsAttributes.self) { context in
            // Lock screen/banner UI goes here
            VStack {
                Text("Hello \(context.state.emoji)")
            }
            .activityBackgroundTint(Color.cyan)
            .activitySystemActionForegroundColor(Color.black)

        } dynamicIsland: { context in
            DynamicIsland {
                // Expanded UI goes here.  Compose the expanded UI through
                // various regions, like leading/trailing/center/bottom
                DynamicIslandExpandedRegion(.leading) {
                    Text("Leading")
                }
                DynamicIslandExpandedRegion(.trailing) {
                    Text("Trailing")
                }
                DynamicIslandExpandedRegion(.bottom) {
                    Text("Bottom \(context.state.emoji)")
                    // more content
                }
            } compactLeading: {
                Text("L")
            } compactTrailing: {
                Text("T \(context.state.emoji)")
            } minimal: {
                Text(context.state.emoji)
            }
            .widgetURL(URL(string: "http://www.apple.com"))
            .keylineTint(Color.red)
        }
    }
}

extension CashFlowWidgetsAttributes {
    fileprivate static var preview: CashFlowWidgetsAttributes {
        CashFlowWidgetsAttributes(name: "World")
    }
}

extension CashFlowWidgetsAttributes.ContentState {
    fileprivate static var smiley: CashFlowWidgetsAttributes.ContentState {
        CashFlowWidgetsAttributes.ContentState(emoji: "😀")
     }
     
     fileprivate static var starEyes: CashFlowWidgetsAttributes.ContentState {
         CashFlowWidgetsAttributes.ContentState(emoji: "🤩")
     }
}

#Preview("Notification", as: .content, using: CashFlowWidgetsAttributes.preview) {
   CashFlowWidgetsLiveActivity()
} contentStates: {
    CashFlowWidgetsAttributes.ContentState.smiley
    CashFlowWidgetsAttributes.ContentState.starEyes
}
