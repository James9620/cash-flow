//
//  ContentView.swift
//  cash-flow
//
//  Created by James Larkin on 6/12/26.
//

import SwiftUI
import SwiftData

struct ContentView: View {
    var body: some View {
        TabView {
            VStack {
                Image(systemName: "globe")
                    .imageScale(.large)
                    .foregroundStyle(.tint)
                Text("Hello, world!")
            }
            .padding()
            .tabItem {
                Label("Home", systemImage: "house")
            }

            SwiftDataDebugView()
                .tabItem {
                    Label("Debug", systemImage: "ladybug")
                }
        }
    }
}

#Preview {
    ContentView()
        .modelContainer(for: [
            Widget.self,
            Transaction.self,
            IncomeEvent.self,
            UserSettings.self
        ], inMemory: true)
}
