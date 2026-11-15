import SwiftUI
import UIKit

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
                providerSection
                detailsSection
                submitSection
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
        .task { await model.loadProviders() }
        // Closing does not cancel the shell-owned save/run or create a new attempt.
        .onDisappear { reconcileTask?.cancel() }
    }

    private var providerSection: some View {
        Section {
            Label("ألمانيا فقط · شقق ومنازل وغرف للإيجار", systemImage: "mappin.and.ellipse")
                .font(.footnote)
                .foregroundStyle(.secondary)

            Menu {
                ForEach(model.availableProviders) { source in
                    Button {
                        focusedField = nil
                        model.chooseProvider(source)
                    } label: {
                        if source == model.selectedProvider {
                            Label(source.title, systemImage: "checkmark")
                        } else {
                            Text(source.title)
                        }
                    }
                }
            } label: {
                HStack(spacing: 12) {
                    Image(systemName: "building.2.crop.circle")
                        .font(.title2)
                        .foregroundStyle(.tint)
                    VStack(alignment: .leading, spacing: 4) {
                        Text("الموقع العقاري").font(.caption).foregroundStyle(.secondary)
                        Text(model.providerCatalogState == .ready ? model.selectedProvider.title : "اختر الموقع")
                            .font(.headline)
                            .foregroundStyle(.primary)
                    }
                    Spacer()
                    Image(systemName: "chevron.down")
                        .foregroundStyle(.secondary)
                }
                .frame(minHeight: 48)
                .contentShape(Rectangle())
            }
            .disabled(model.providerCatalogState != .ready ||
                      model.hasAttemptedCreate || model.isBusy)

            switch model.providerCatalogState {
            case .idle, .loading:
                HStack(spacing: 8) {
                    ProgressView()
                    Text("جارٍ قراءة المواقع المدعومة من الخادم...")
                        .foregroundStyle(.secondary)
                }
                .font(.footnote)
            case .ready:
                Text("مواقع متاحة من الخادم: \(model.availableProviders.count)")
                    .font(.footnote)
                    .foregroundStyle(.secondary)
            case .failed:
                HStack {
                    Text("تعذّر التحقق من مواقع البحث.")
                        .font(.footnote)
                        .foregroundStyle(.secondary)
                    Spacer()
                    Button("إعادة المحاولة") {
                        Task { await model.loadProviders() }
                    }
                    .disabled(model.isBusy || model.hasAttemptedCreate)
                }
            }
        } header: {
            Text("اختر الموقع")
        } footer: {
            Text("تظهر فقط مواقع الإيجار الألمانية المسجّلة في Fredy. ظهور الموقع لا يضمن نجاح جلب الإعلانات.")
        }
    }

    private var detailsSection: some View {
        Section {
            TextField("jobs.search_name", text: $model.name)
                .focused($focusedField, equals: .name)
                .submitLabel(.next)
                .onSubmit { focusedField = .url }
                .accessibilityIdentifier("jobs.search_name_input")

            TextField("jobs.search_url", text: $model.urlText, axis: .vertical)
                .lineLimit(2...4)
                .keyboardType(.URL)
                .textInputAutocapitalization(.never)
                .autocorrectionDisabled()
                .environment(\.layoutDirection, .leftToRight)
                .multilineTextAlignment(.leading)
                .focused($focusedField, equals: .url)
                .accessibilityIdentifier("jobs.search_url_input")

            HStack(alignment: .center) {
                Label("رابط نتائج البحث", systemImage: "link")
                    .font(.footnote)
                    .foregroundStyle(.secondary)
                Spacer()
                Button {
                    if let pasted = UIPasteboard.general.string {
                        model.urlText = pasted
                        focusedField = nil
                    }
                } label: {
                    Label("لصق الرابط", systemImage: "doc.on.clipboard")
                }
                .font(.subheadline.weight(.medium))
            }
            .frame(minHeight: 36)
        } header: {
            Text("تفاصيل البحث")
        } footer: {
            VStack(alignment: .leading, spacing: 5) {
                Text(model.selectedProvider.urlHint)
                Text("احتفظ بفلاتر المدينة والسعر والإيجار في الرابط. لن نبدّل الرابط أو نبحث عن عقارات للبيع.")
            }
        }
        .disabled(model.hasAttemptedCreate || model.isBusy)
    }

    private var submitSection: some View {
        Section {
            Button("jobs.save_search") {
                focusedField = nil
                onSave()
            }
            .buttonStyle(.borderedProminent)
            .frame(maxWidth: .infinity, minHeight: 48)
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
            Text("jobs.one_search_note")
            Text(LocalizedStringKey(model.providerOutcomeUnknown))
        }
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
