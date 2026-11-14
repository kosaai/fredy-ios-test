import SwiftUI

@MainActor
struct AddSearchView: View {
    @Bindable var model: AddSearchModel
    let onSave: () -> Void
    let onSelect: (String) -> Void
    @Environment(\.dismiss) private var dismiss
    @State private var reconcileTask: Task<Void, Never>?
    @FocusState private var focusedField: Field?
    private enum Field: Hashable { case name, url }

    var body: some View {
        NavigationStack {
            Form {
                Section {
                    TextField("jobs.search_name", text: $model.name)
                        .focused($focusedField, equals: .name)
                        .submitLabel(.next)
                        .onSubmit { focusedField = .url }
                        .accessibilityIdentifier("jobs.search_name_input")
                    TextField("jobs.search_url", text: $model.urlText, axis: .vertical)
                        .keyboardType(.URL)
                        .textInputAutocapitalization(.never)
                        .autocorrectionDisabled()
                        .environment(\.layoutDirection, .leftToRight)
                        .multilineTextAlignment(.leading)
                        .focused($focusedField, equals: .url)
                        .accessibilityIdentifier("jobs.search_url_input")
                } header: {
                    Text("jobs.add_title")
                } footer: {
                    Text("jobs.one_search_note")
                }
                .disabled(model.hasAttemptedCreate || model.isBusy)

                Section {
                    Button("jobs.save_search") {
                        focusedField = nil
                        onSave()
                    }
                    .buttonStyle(.borderedProminent)
                    .frame(maxWidth: .infinity, minHeight: 44)
                    .disabled(!model.canSubmit)
                    .accessibilityIdentifier("jobs.save_search_button")
                    SearchProgressView(model: model)
                    if model.phase == .uncertain {
                        Button("jobs.reconcile") {
                            guard reconcileTask == nil else { return }
                            reconcileTask = Task {
                                await model.reconcile()
                                reconcileTask = nil
                            }
                        }
                        .frame(minHeight: 44)
                    }
                    if let id = model.savedJobID {
                        Button("jobs.show_results") {
                            onSelect(id)
                            dismiss()
                        }
                        .frame(minHeight: 44)
                    }
                } footer: {
                    Text(LocalizedStringKey(model.providerOutcomeUnknown))
                }
            }
            .navigationTitle("jobs.add_title")
            .navigationBarTitleDisplayMode(.inline)
            .scrollDismissesKeyboard(.interactively)
            .toolbar {
                ToolbarItem(placement: .cancellationAction) {
                    Button("jobs.close") { dismiss() }
                }
            }
        }
        .environment(\.layoutDirection, .rightToLeft)
        .environment(\.locale, Locale(identifier: "ar"))
        .interactiveDismissDisabled(model.isBusy)
        // Closing does not cancel the shell-owned save/run or create a new attempt.
        .onDisappear { reconcileTask?.cancel() }
    }
}

@MainActor
struct SearchProgressView: View {
    let model: AddSearchModel

    var body: some View {
        VStack(alignment: .leading, spacing: 8) {
            if model.isBusy {
                ProgressView(LocalizedStringKey(model.statusKey))
            } else {
                Text(LocalizedStringKey(model.statusKey))
                    .fixedSize(horizontal: false, vertical: true)
            }
        }
        .accessibilityIdentifier("jobs.search_progress")
    }
}
