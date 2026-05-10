import SwiftUI

/// Dual-purpose form for creating a new subscription or editing an existing
/// one. Pass `editing: nil` to add, or an existing `Subscription` to edit
/// in-place. Validation requirements (red asterisks): name, billing cycle,
/// next renewal date.
struct AddSubscriptionView: View {
    @Bindable var store: SubscriptionStore
    @Binding var isPresented: Bool
    let editing: Subscription?

    @State private var providerKey: String
    @State private var name: String
    @State private var plan: String
    @State private var costString: String
    @State private var currency: String
    @State private var billingCycle: BillingCycle
    @State private var nextRenewalDate: Date
    @State private var quotaResetCycle: QuotaResetCycle?
    @State private var notes: String
    @State private var apiKey: String = ""
    @State private var keychainError: String?
    @State private var didAttemptSubmit: Bool = false
    @State private var showDeleteConfirm: Bool = false

    init(
        store: SubscriptionStore,
        isPresented: Binding<Bool>,
        editing: Subscription? = nil
    ) {
        self.store = store
        self._isPresented = isPresented
        self.editing = editing

        if let sub = editing {
            _providerKey = State(initialValue: sub.providerKey)
            _name = State(initialValue: sub.name)
            _plan = State(initialValue: sub.plan)
            _costString = State(initialValue: Self.format(decimal: sub.cost))
            _currency = State(initialValue: sub.currency)
            _billingCycle = State(initialValue: sub.billingCycle)
            _nextRenewalDate = State(initialValue: sub.nextRenewalDate)
            _quotaResetCycle = State(initialValue: sub.quotaResetCycle)
            _notes = State(initialValue: sub.notes ?? "")
        } else {
            _providerKey = State(initialValue: ManualProvider.key)
            _name = State(initialValue: "")
            _plan = State(initialValue: "")
            _costString = State(initialValue: "")
            _currency = State(initialValue: "USD")
            _billingCycle = State(initialValue: .monthly)
            _nextRenewalDate = State(
                initialValue: Calendar.current.date(byAdding: .month, value: 1, to: .now) ?? .now
            )
            _quotaResetCycle = State(initialValue: nil)
            _notes = State(initialValue: "")
        }
    }

    private var descriptors: [ProviderDescriptor] {
        ProviderRegistry.shared.descriptors
    }

    private var manualDescriptor: ProviderDescriptor? {
        descriptors.first { $0.key == ManualProvider.key }
    }

    private var otherDescriptors: [ProviderDescriptor] {
        descriptors.filter { $0.key != ManualProvider.key }
    }

    private var selectedDescriptor: ProviderDescriptor? {
        descriptors.first { $0.key == providerKey }
    }

    private var isEditing: Bool { editing != nil }

    var body: some View {
        VStack(spacing: 0) {
            Form {
                Section("Provider") {
                    Picker("Type", selection: $providerKey) {
                        if let manual = manualDescriptor {
                            Text(manual.displayName).tag(manual.key)
                        }
                        Divider()
                        ForEach(otherDescriptors) { descriptor in
                            Text(descriptor.displayName).tag(descriptor.key)
                        }
                    }
                    if selectedDescriptor?.requiresCredential == true {
                        SecureField(
                            isEditing ? "API key (leave blank to keep)" : "API key",
                            text: $apiKey
                        )
                        .textContentType(.password)
                        errorRow(apiKeyError)
                    }
                }

                Section("Service") {
                    LabeledContent {
                        TextField("", text: $name, prompt: Text("e.g. Spotify"))
                    } label: {
                        requiredLabel("Name")
                    }
                    errorRow(nameError)
                    TextField("Plan", text: $plan, prompt: Text("e.g. Family"))
                }

                Section("Billing") {
                    HStack {
                        Picker("Cost", selection: $currency) {
                                ForEach(CurrencyCatalog.common) { entry in
                                    Text("\(entry.code) (\(entry.symbol))").tag(entry.code)
                                }
                                if CurrencyCatalog.common.first(where: { $0.code == currency }) == nil {
                                    Text(currency).tag(currency)
                                }
                            }
                            .pickerStyle(.menu)
                            .frame(width: 240)
                            TextField("Amount", text: $costString, prompt: Text("16.99"))
                                .labelsHidden()
                        }
                    errorRow(costError)

                    LabeledContent {
                        Picker("", selection: $billingCycle) {
                            ForEach(BillingCycle.allCases) { cycle in
                                Text(cycle.displayName).tag(cycle)
                            }
                        }
                        .labelsHidden()
                    } label: {
                        requiredLabel("Cycle")
                    }

                    LabeledContent {
                        DatePicker(
                            "",
                            selection: $nextRenewalDate,
                            displayedComponents: .date
                        )
                        .labelsHidden()
                    } label: {
                        requiredLabel("Next renewal")
                    }
                    errorRow(renewalError)
                }

                Section("Quota") {
                    Picker("Reset cycle", selection: quotaBinding) {
                        Text("None").tag(QuotaResetCycle?.none)
                        ForEach(QuotaResetCycle.allCases) { cycle in
                            Text(cycle.displayName).tag(QuotaResetCycle?.some(cycle))
                        }
                    }
                }

                Section("Notes") {
                    TextField(
                        "Notes",
                        text: $notes,
                        prompt: Text("Optional"),
                        axis: .vertical
                    )
                    .lineLimit(3...6)
                }

                if let keychainError {
                    Section {
                        Label(keychainError, systemImage: "exclamationmark.triangle.fill")
                            .foregroundStyle(.orange)
                    }
                }
            }
            .formStyle(.grouped)

            HStack {
                if isEditing {
                    Button(role: .destructive) {
                        showDeleteConfirm = true
                    } label: {
                        Label("Delete", systemImage: "trash")
                    }
                }
                Button("Cancel") { isPresented = false }
                    .keyboardShortcut(.cancelAction)
                Spacer()
                Button(isEditing ? "Update" : "Add", action: attemptSave)
                    .keyboardShortcut(.defaultAction)
            }
            .padding(12)
        }
        .frame(width: 380, height: 520)
        .confirmationDialog(
            "Delete \(editing?.name ?? "subscription")?",
            isPresented: $showDeleteConfirm,
            titleVisibility: .visible
        ) {
            Button("Delete", role: .destructive, action: deleteSubscription)
            Button("Cancel", role: .cancel) {}
        } message: {
            Text("This permanently removes the subscription and any stored credentials.")
        }
    }

    // MARK: - Helpers

    private var quotaBinding: Binding<QuotaResetCycle?> {
        Binding(get: { quotaResetCycle }, set: { quotaResetCycle = $0 })
    }

    @ViewBuilder
    private func requiredLabel(_ title: String) -> some View {
        HStack(spacing: 2) {
            Text(title)
            Text("*").foregroundStyle(.red)
        }
    }

    // MARK: - Validation

    private var nameError: String? {
        name.trimmingCharacters(in: .whitespaces).isEmpty ? "Name is required." : nil
    }

    private var costError: String? {
        let trimmed = costString.trimmingCharacters(in: .whitespaces)
        if trimmed.isEmpty { return nil }
        guard let cost = parsedCost else { return "Enter a valid number (e.g. 9.99)." }
        if cost < 0 { return "Cost cannot be negative." }
        return nil
    }

    private var renewalError: String? {
        let today = Calendar.current.startOfDay(for: .now)
        let renewal = Calendar.current.startOfDay(for: nextRenewalDate)
        return renewal < today ? "Next renewal is in the past." : nil
    }

    private var apiKeyError: String? {
        guard selectedDescriptor?.requiresCredential == true else { return nil }
        let blank = apiKey.trimmingCharacters(in: .whitespaces).isEmpty
        guard blank else { return nil }
        // Blank is allowed only when editing and the existing credential is
        // for the same provider (i.e. user is intentionally keeping it).
        if let existing = editing,
           existing.providerKey == providerKey,
           existing.credential != nil {
            return nil
        }
        return "API key is required for this provider."
    }

    private var validationErrors: [String] {
        [nameError, costError, renewalError, apiKeyError].compactMap { $0 }
    }

    private var isValid: Bool { validationErrors.isEmpty }

    private var parsedCost: Decimal? {
        let trimmed = costString.trimmingCharacters(in: .whitespaces)
        guard !trimmed.isEmpty else { return nil }
        return Decimal(string: trimmed.replacingOccurrences(of: ",", with: "."))
    }

    @ViewBuilder
    private func errorRow(_ message: String?) -> some View {
        if didAttemptSubmit, let message {
            Label(message, systemImage: "exclamationmark.circle.fill")
                .foregroundStyle(.red)
                .font(.caption)
        }
    }

    private static func format(decimal: Decimal) -> String {
        if decimal == 0 { return "" }
        var copy = decimal
        var rounded = Decimal()
        NSDecimalRound(&rounded, &copy, 2, .plain)
        return "\(rounded)"
    }

    private func attemptSave() {
        didAttemptSubmit = true
        guard isValid else { return }
        save()
    }

    private func deleteSubscription() {
        guard let existing = editing else { return }
        if let cred = existing.credential {
            try? KeychainStore(service: cred.keychainService)
                .deleteSecret(account: cred.keychainAccount)
        }
        store.delete(existing)
        isPresented = false
    }

    private func save() {
        let trimmedName = name.trimmingCharacters(in: .whitespaces)
        let resolvedCurrency = currency.isEmpty ? "USD" : currency.uppercased()
        let resolvedCost = parsedCost ?? Decimal.zero

        if let existing = editing {
            updateExisting(
                existing,
                name: trimmedName,
                cost: resolvedCost,
                currency: resolvedCurrency
            )
        } else {
            createNew(
                name: trimmedName,
                cost: resolvedCost,
                currency: resolvedCurrency
            )
        }
    }

    private func createNew(name: String, cost: Decimal, currency: String) {
        let trimmedNotes = notes.trimmingCharacters(in: .whitespacesAndNewlines)
        let trimmedPlan = plan.trimmingCharacters(in: .whitespaces)
        let trimmedKey = apiKey.trimmingCharacters(in: .whitespaces)
        let subscription = Subscription(
            name: name,
            providerKey: providerKey,
            plan: trimmedPlan,
            cost: cost,
            currency: currency,
            billingCycle: billingCycle,
            nextRenewalDate: nextRenewalDate,
            quotaResetCycle: quotaResetCycle,
            notes: trimmedNotes.isEmpty ? nil : trimmedNotes
        )

        if selectedDescriptor?.requiresCredential == true {
            let service = "com.likkee.\(providerKey)"
            let keychain = KeychainStore(service: service)
            do {
                try keychain.setSecret(trimmedKey, account: subscription.id.uuidString)
                subscription.credential = ProviderCredential(
                    keychainAccount: subscription.id.uuidString,
                    keychainService: service
                )
            } catch {
                keychainError = "Could not save API key: \(error)"
                return
            }
        }

        store.create(subscription)
        isPresented = false
    }

    private func updateExisting(_ existing: Subscription, name: String, cost: Decimal, currency: String) {
        let didChangeProvider = existing.providerKey != providerKey

        let trimmedNotes = notes.trimmingCharacters(in: .whitespacesAndNewlines)
        let trimmedPlan = plan.trimmingCharacters(in: .whitespaces)
        store.update(existing) { sub in
            sub.name = name
            sub.providerKey = providerKey
            sub.plan = trimmedPlan
            sub.cost = cost
            sub.currency = currency
            sub.billingCycle = billingCycle
            sub.nextRenewalDate = nextRenewalDate
            sub.quotaResetCycle = quotaResetCycle
            sub.notes = trimmedNotes.isEmpty ? nil : trimmedNotes
        }

        // Credential management on edit.
        let needsCredential = selectedDescriptor?.requiresCredential == true
        let trimmedKey = apiKey.trimmingCharacters(in: .whitespaces)

        if needsCredential {
            let service = "com.likkee.\(providerKey)"
            // Provider switched: clear old credential entry.
            if didChangeProvider, let old = existing.credential {
                try? KeychainStore(service: old.keychainService).deleteSecret(account: old.keychainAccount)
                existing.credential = nil
            }
            if !trimmedKey.isEmpty {
                let keychain = KeychainStore(service: service)
                do {
                    try keychain.setSecret(trimmedKey, account: existing.id.uuidString)
                    if existing.credential == nil {
                        existing.credential = ProviderCredential(
                            keychainAccount: existing.id.uuidString,
                            keychainService: service
                        )
                    } else {
                        existing.credential?.keychainService = service
                    }
                } catch {
                    keychainError = "Could not save API key: \(error)"
                    return
                }
            }
        } else if let old = existing.credential {
            // Switched away from a credentialed provider entirely.
            try? KeychainStore(service: old.keychainService).deleteSecret(account: old.keychainAccount)
            existing.credential = nil
        }

        isPresented = false
    }
}
