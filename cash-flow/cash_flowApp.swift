//
//  cash_flowApp.swift
//  cash-flow
//
//  Created by James Larkin on 6/12/26.
//

import SwiftUI
import SwiftData

@main
struct cash_flowApp: App {
    // This root-owned session decides whether the app shows Sign in with Apple or the main tabs.
    @State private var backendSession = BackendSession()

    // This service owns RevenueCat status for the signed-in user and keeps purchase logic out of the views.
    @State private var subscriptionManager = SubscriptionManager()

    // The ModelContainer is the top-level SwiftData object that owns the app's saved database.
    private let modelContainer: ModelContainer

    // The ModelContext is the main place where app code will insert, fetch, edit, and delete SwiftData models.
    private let modelContext: ModelContext

    init() {
        // The schema lists every @Model class that SwiftData should know how to save.
        let schema = Schema([
            BankConnection.self,
            Widget.self,
            Transaction.self,
            IncomeEvent.self,
            UserSettings.self
        ])

        // This configuration tells SwiftData to store the data on disk instead of only keeping it in memory.
        let configuration = ModelConfiguration(schema: schema, isStoredInMemoryOnly: false)

        do {
            // The ModelContainer owns the SwiftData store for every @Model type in this app.
            modelContainer = try ModelContainer(for: schema, configurations: [configuration])

            // The ModelContext is the main workspace views and view models will use to insert, fetch, update, and delete models.
            modelContext = modelContainer.mainContext
        } catch {
            fatalError("Failed to create SwiftData model container: \(error)")
        }
    }

    var body: some Scene {
        WindowGroup {
            RootSessionView(session: backendSession, subscriptionManager: subscriptionManager)
        }
        // This makes the same SwiftData container available to the whole app through SwiftUI's environment.
        .modelContainer(modelContainer)
    }
}

private struct RootSessionView: View {
    let session: BackendSession
    let subscriptionManager: SubscriptionManager

    var body: some View {
        if session.isSignedIn {
            ContentView(session: session, subscriptionManager: subscriptionManager)
        } else {
            SignInView(session: session)
                .onAppear {
                    subscriptionManager.clearForSignOut()
                }
        }
    }
}
