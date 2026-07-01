//
//  OnboardingView.swift
//  cash-flow
//
//  Created by Codex on 7/1/26.
//

import SwiftData
import SwiftUI
import WidgetKit

enum OnboardingGate {
    static func shouldShowOnboarding(settings: UserSettings?) -> Bool {
        settings?.onboardingComplete != true
    }
}

enum OnboardingStep: Int, CaseIterable, Identifiable {
    case welcome
    case incomeSplit
    case bankConnection
    case widgetSetup

    var id: Int {
        rawValue
    }

    var title: String {
        switch self {
        case .welcome:
            return "Cash Flow"
        case .incomeSplit:
            return "Income Split"
        case .bankConnection:
            return "Bank Connection"
        case .widgetSetup:
            return "Widget Setup"
        }
    }

    var subtitle: String {
        switch self {
        case .welcome:
            return "Track what you can still spend without turning the app into a budgeting chore."
        case .incomeSplit:
            return "Choose how much of each paycheck should stay out of discretionary spending."
        case .bankConnection:
            return "Connect Plaid now, or skip and do it later from the Bank tab."
        case .widgetSetup:
            return "Add the Discretionary Number widget from the iOS Home Screen widget picker."
        }
    }
}

struct OnboardingSettingsDraft: Equatable {
    var savingsPercentageText: String
    var billsReservePercentageText: String
    var subscriptionStatus: SubscriptionStatus

    func validatedValues() throws -> OnboardingSplitValues {
        let savingsPercentage = try percentage(from: savingsPercentageText, field: "Savings percentage")
        let billsReservePercentage = subscriptionStatus == .pro
            ? try percentage(from: billsReservePercentageText, field: "Bills / Reserve percentage")
            : 0

        guard IncomeSplit.canSave(
            savingsPercentage: savingsPercentage,
            billsReservePercentage: billsReservePercentage,
            subscriptionStatus: subscriptionStatus
        ) else {
            throw OnboardingSettingsError.splitOverLimit
        }

        return OnboardingSplitValues(
            savingsPercentage: savingsPercentage,
            billsReservePercentage: billsReservePercentage
        )
    }

    func apply(to settings: UserSettings, markComplete: Bool) throws {
        let values = try validatedValues()
        settings.savingsPercentage = values.savingsPercentage
        settings.billsReservePercentage = values.billsReservePercentage
        settings.subscriptionStatus = subscriptionStatus

        if markComplete {
            settings.onboardingComplete = true
        }
    }

    private func percentage(from text: String, field: String) throws -> Double {
        let normalized = text.trimmingCharacters(in: .whitespacesAndNewlines)
        guard let value = Double(normalized), (0...100).contains(value) else {
            throw OnboardingSettingsError.invalidPercentage(field)
        }

        return value
    }
}

struct OnboardingSplitValues: Equatable {
    let savingsPercentage: Double
    let billsReservePercentage: Double
}

enum OnboardingSettingsError: LocalizedError, Equatable {
    case invalidPercentage(String)
    case splitOverLimit

    var errorDescription: String? {
        switch self {
        case .invalidPercentage(let field):
            return "\(field) must be a number from 0 to 100."
        case .splitOverLimit:
            return "Savings and bills/reserve cannot add up to more than 100%."
        }
    }
}

struct OnboardingView: View {
    @Environment(\.modelContext) private var modelContext

    @Query private var userSettings: [UserSettings]
    @Query private var bankConnections: [BankConnection]

    let session: BackendSession
    let subscriptionManager: SubscriptionManager

    @State private var currentStep: OnboardingStep = .welcome
    @State private var savingsPercentage = "20"
    @State private var billsReservePercentage = "0"
    @State private var statusMessage: String?
    @State private var errorMessage: String?
    @State private var bankViewModel = BankConnectionViewModel()
    @State private var presentedSheet: OnboardingSheet?

    private var settings: UserSettings? {
        userSettings.first
    }

    private var bankConnection: BankConnection? {
        bankConnections.first
    }

    var body: some View {
        NavigationStack {
            ZStack {
                CashFlowTheme.background
                    .ignoresSafeArea()

                VStack(spacing: 0) {
                    ScrollView {
                        VStack(alignment: .leading, spacing: 18) {
                            progressHeader
                            stepContent
                            messageArea
                        }
                        .padding()
                    }

                    footerControls
                }
            }
            .navigationTitle(currentStep.title)
            .toolbarBackground(CashFlowTheme.background, for: .navigationBar)
            .toolbarColorScheme(.dark, for: .navigationBar)
            .toolbar {
                Button("Sign Out") {
                    subscriptionManager.clearForSignOut()
                    session.signOut()
                }
                .foregroundStyle(CashFlowTheme.accent)
            }
        }
        .task {
            loadDraftsFromSavedData()
        }
        .onChange(of: userSettingsSignature) {
            loadDraftsFromSavedData()
        }
        .sheet(item: $presentedSheet) { sheet in
            switch sheet {
            case .plaid(let linkToken):
                PlaidLinkView(
                    linkToken: linkToken,
                    onSuccess: { publicToken in
                        presentedSheet = nil

                        Task {
                            await bankViewModel.handlePublicToken(publicToken, context: modelContext)
                        }
                    },
                    onExit: {
                        presentedSheet = nil
                    }
                )

            case .pro:
                ProView(subscriptionManager: subscriptionManager)
            }
        }
    }

    private var progressHeader: some View {
        CashFlowPanel {
            VStack(alignment: .leading, spacing: 14) {
                HStack(spacing: 8) {
                    ForEach(OnboardingStep.allCases) { step in
                        Capsule()
                            .fill(step.rawValue <= currentStep.rawValue ? CashFlowTheme.accent : CashFlowTheme.track)
                            .frame(height: 6)
                    }
                }

                Text(currentStep.title)
                    .font(.system(size: 34, weight: .black))
                    .foregroundStyle(CashFlowTheme.primaryText)
                    .fixedSize(horizontal: false, vertical: true)

                Text(currentStep.subtitle)
                    .font(.subheadline)
                    .foregroundStyle(CashFlowTheme.secondaryText)
                    .fixedSize(horizontal: false, vertical: true)
            }
        }
    }

    @ViewBuilder
    private var stepContent: some View {
        switch currentStep {
        case .welcome:
            welcomeStep
        case .incomeSplit:
            incomeSplitStep
        case .bankConnection:
            bankConnectionStep
        case .widgetSetup:
            widgetSetupStep
        }
    }

    private var welcomeStep: some View {
        CashFlowPanel {
            VStack(alignment: .leading, spacing: 14) {
                CashFlowStatusPill("Discretionary Number v1", color: CashFlowTheme.accent, systemImage: "number")

                Text("Your Home Screen widget will show one clear number: what is available for discretionary spending right now.")
                    .font(.headline)
                    .foregroundStyle(CashFlowTheme.primaryText)
                    .fixedSize(horizontal: false, vertical: true)

                Text("Progress Bar and Bill Stack are still planned for later, so this setup keeps the first version focused.")
                    .font(.subheadline)
                    .foregroundStyle(CashFlowTheme.secondaryText)
                    .fixedSize(horizontal: false, vertical: true)
            }
        }
    }

    private var incomeSplitStep: some View {
        VStack(alignment: .leading, spacing: 18) {
            CashFlowPanel {
                VStack(alignment: .leading, spacing: 14) {
                    CashFlowPercentageField(
                        title: "Savings Percentage",
                        caption: "If you enter 20, direct deposits add the remaining 80% to discretionary balance.",
                        text: $savingsPercentage
                    )

                    if subscriptionManager.isPro {
                        Divider()
                            .overlay(CashFlowTheme.track)

                        CashFlowPercentageField(
                            title: "Bills / Reserve Percentage",
                            caption: "Pro users can reserve a second bucket before discretionary spending is calculated.",
                            text: $billsReservePercentage
                        )
                    }

                    CashFlowAllocationBar(
                        savingsPercentage: draftSavingsPercentage,
                        billsReservePercentage: subscriptionManager.isPro ? draftBillsReservePercentage : 0,
                        isPro: subscriptionManager.isPro
                    )
                }
            }

            CashFlowPanel {
                VStack(alignment: .leading, spacing: 12) {
                    HStack {
                        Text("Cash Flow Pro")
                            .font(.headline.weight(.bold))
                            .foregroundStyle(CashFlowTheme.primaryText)

                        Spacer()

                        CashFlowStatusPill(subscriptionManager.isPro ? "Active" : "Optional", color: subscriptionManager.isPro ? CashFlowTheme.success : CashFlowTheme.accent)
                    }

                    Text("Advanced income split is available whenever you want it. Free setup works with one savings percentage.")
                        .font(.subheadline)
                        .foregroundStyle(CashFlowTheme.secondaryText)
                        .fixedSize(horizontal: false, vertical: true)

                    if !subscriptionManager.isPro {
                        Button {
                            presentedSheet = .pro
                        } label: {
                            Label("View Pro", systemImage: "creditcard")
                                .font(.headline)
                                .frame(maxWidth: .infinity)
                        }
                        .buttonStyle(.bordered)
                        .tint(CashFlowTheme.accent)
                    }
                }
            }
        }
    }

    private var bankConnectionStep: some View {
        CashFlowPanel {
            VStack(alignment: .leading, spacing: 14) {
                HStack {
                    Text(bankTitle)
                        .font(.headline.weight(.bold))
                        .foregroundStyle(CashFlowTheme.primaryText)

                    Spacer()

                    CashFlowStatusPill(bankPillTitle, color: bankPillColor)
                }

                Text(bankMessage)
                    .font(.subheadline)
                    .foregroundStyle(CashFlowTheme.secondaryText)
                    .fixedSize(horizontal: false, vertical: true)

                if bankViewModel.isLoading {
                    HStack(spacing: 10) {
                        ProgressView()
                            .tint(CashFlowTheme.accent)

                        Text("Working with your bank connection...")
                            .font(.subheadline.weight(.semibold))
                            .foregroundStyle(CashFlowTheme.secondaryText)
                    }
                }

                Button {
                    startPlaidLink()
                } label: {
                    Label(bankButtonTitle, systemImage: "building.columns")
                        .font(.headline)
                        .frame(maxWidth: .infinity)
                }
                .buttonStyle(.borderedProminent)
                .tint(CashFlowTheme.accent)
                .disabled(bankViewModel.isLoading)
            }
        }
    }

    private var widgetSetupStep: some View {
        CashFlowPanel {
            VStack(alignment: .leading, spacing: 14) {
                CashFlowStatusPill("Manual iOS step", color: CashFlowTheme.warning, systemImage: "square.grid.2x2")

                Text("Add the widget from your iPhone Home Screen.")
                    .font(.headline.weight(.bold))
                    .foregroundStyle(CashFlowTheme.primaryText)

                VStack(alignment: .leading, spacing: 8) {
                    Text("1. Long-press the Home Screen.")
                    Text("2. Tap Edit, then Add Widget.")
                    Text("3. Search Cash Flow and choose Discretionary Number.")
                }
                .font(.subheadline)
                .foregroundStyle(CashFlowTheme.secondaryText)
                .fixedSize(horizontal: false, vertical: true)

                CashFlowMiniWidgetPreview(balance: 420, statusText: "Synced")
                    .padding(.top, 6)
                    .frame(maxWidth: .infinity)
            }
        }
    }

    @ViewBuilder
    private var messageArea: some View {
        if let statusMessage {
            Text(statusMessage)
                .font(.subheadline.weight(.semibold))
                .foregroundStyle(CashFlowTheme.success)
                .fixedSize(horizontal: false, vertical: true)
        }

        if let recoveryMessage = errorMessage ?? bankViewModel.errorMessage {
            Text(recoveryMessage)
                .font(.subheadline)
                .foregroundStyle(CashFlowTheme.error)
                .fixedSize(horizontal: false, vertical: true)
        }
    }

    private var footerControls: some View {
        HStack(spacing: 12) {
            Button {
                goBack()
            } label: {
                Label("Back", systemImage: "chevron.left")
                    .font(.headline)
                    .frame(maxWidth: .infinity)
            }
            .buttonStyle(.bordered)
            .tint(CashFlowTheme.accent)
            .disabled(currentStep == .welcome)

            Button {
                continueForward()
            } label: {
                Label(primaryButtonTitle, systemImage: currentStep == .widgetSetup ? "checkmark.circle" : "chevron.right")
                    .font(.headline)
                    .frame(maxWidth: .infinity)
            }
            .buttonStyle(.borderedProminent)
            .tint(CashFlowTheme.accent)
        }
        .padding()
        .background(CashFlowTheme.background)
    }

    private var primaryButtonTitle: String {
        currentStep == .widgetSetup ? "Finish Setup" : "Continue"
    }

    private var bankTitle: String {
        switch bankConnection?.status ?? .notConnected {
        case .notConnected:
            return "No Bank Connected"
        case .connected:
            return "Bank Connected"
        case .needsReconnect:
            return "Reconnect Needed"
        case .error:
            return "Bank Needs Attention"
        }
    }

    private var bankMessage: String {
        switch bankConnection?.status ?? .notConnected {
        case .notConnected:
            return "Plaid lets Cash Flow import transactions and detect direct deposits. You can skip this and connect later."
        case .connected:
            return "Cash Flow can import new transactions and refresh the widget snapshot."
        case .needsReconnect:
            return "Plaid needs you to reconnect before transaction syncing can continue."
        case .error:
            return bankConnection?.lastErrorMessage ?? "The last bank action did not finish."
        }
    }

    private var bankPillTitle: String {
        switch bankConnection?.status ?? .notConnected {
        case .notConnected:
            return "Optional"
        case .connected:
            return "Ready"
        case .needsReconnect:
            return "Reconnect"
        case .error:
            return "Retry"
        }
    }

    private var bankPillColor: Color {
        switch bankConnection?.status ?? .notConnected {
        case .notConnected:
            return CashFlowTheme.secondaryText
        case .connected:
            return CashFlowTheme.success
        case .needsReconnect:
            return CashFlowTheme.warning
        case .error:
            return CashFlowTheme.error
        }
    }

    private var bankButtonTitle: String {
        (bankConnection?.status ?? .notConnected) == .connected ? "Reconnect Bank" : "Connect Bank Account"
    }

    private var draftSavingsPercentage: Double {
        Double(savingsPercentage.trimmingCharacters(in: .whitespacesAndNewlines)) ?? settings?.savingsPercentage ?? 0
    }

    private var draftBillsReservePercentage: Double {
        Double(billsReservePercentage.trimmingCharacters(in: .whitespacesAndNewlines)) ?? settings?.billsReservePercentage ?? 0
    }

    private var userSettingsSignature: String {
        settings.map { settings in
            [
                String(settings.savingsPercentage),
                String(settings.billsReservePercentage),
                settings.subscriptionStatus.rawValue,
                String(settings.onboardingComplete)
            ].joined(separator: "|")
        } ?? "no-settings"
    }

    private func loadDraftsFromSavedData() {
        guard let settings else {
            return
        }

        savingsPercentage = formattedNumber(settings.savingsPercentage)
        billsReservePercentage = formattedNumber(settings.billsReservePercentage)
    }

    private func goBack() {
        guard let previousStep = OnboardingStep(rawValue: currentStep.rawValue - 1) else {
            return
        }

        currentStep = previousStep
        clearMessages()
    }

    private func continueForward() {
        do {
            if currentStep == .incomeSplit {
                try saveIncomeSettings(markComplete: false)
            }

            if currentStep == .widgetSetup {
                try saveIncomeSettings(markComplete: true)
                statusMessage = "Setup complete."
                errorMessage = nil
                return
            }

            if let nextStep = OnboardingStep(rawValue: currentStep.rawValue + 1) {
                currentStep = nextStep
                clearMessages()
            }
        } catch {
            statusMessage = nil
            errorMessage = error.localizedDescription
        }
    }

    private func startPlaidLink() {
        do {
            // Save the split first so any deposits imported right after Plaid Link use the user's setup choice.
            try saveIncomeSettings(markComplete: false)
        } catch {
            statusMessage = nil
            errorMessage = error.localizedDescription
            return
        }

        Task {
            if let token = await bankViewModel.connectBank(context: modelContext) {
                presentedSheet = .plaid(linkToken: token)
            }
        }
    }

    private func saveIncomeSettings(markComplete: Bool) throws {
        let settings = try firstOrCreateSettings()
        let draft = OnboardingSettingsDraft(
            savingsPercentageText: savingsPercentage,
            billsReservePercentageText: billsReservePercentage,
            subscriptionStatus: subscriptionManager.subscriptionStatus
        )

        try draft.apply(to: settings, markComplete: markComplete)
        try modelContext.save()

        // Widget data lives outside SwiftData, so export after saving settings.
        try? WidgetSnapshotExporter().export(context: modelContext)
        WidgetCenter.shared.reloadAllTimelines()
    }

    private func firstOrCreateSettings() throws -> UserSettings {
        if let settings {
            return settings
        }

        let settings = UserSettings(subscriptionStatus: subscriptionManager.subscriptionStatus)
        modelContext.insert(settings)
        return settings
    }

    private func clearMessages() {
        statusMessage = nil
        errorMessage = nil
    }

    private func formattedNumber(_ value: Double) -> String {
        let rounded = value.rounded()
        if abs(value - rounded) < 0.001 {
            return String(Int(rounded))
        }

        return String(format: "%.2f", value)
    }
}

private enum OnboardingSheet: Identifiable {
    case plaid(linkToken: String)
    case pro

    var id: String {
        switch self {
        case .plaid:
            return "plaid"
        case .pro:
            return "pro"
        }
    }
}

#Preview {
    OnboardingView(session: .previewSignedIn, subscriptionManager: SubscriptionManager())
        .modelContainer(for: [
            BankConnection.self,
            Widget.self,
            Transaction.self,
            IncomeEvent.self,
            UserSettings.self
        ], inMemory: true)
}
