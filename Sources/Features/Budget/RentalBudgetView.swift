import SwiftUI

/// Personal rental affordability calculation. All values come from the user.
struct RentalBudgetView: View {
    @State private var income = ""
    @State private var expenses = ""
    @State private var rent = ""
    @Environment(\.dismiss) private var dismiss

    private func amount(_ text: String) -> Double? {
        let normalized = text.trimmingCharacters(in: .whitespacesAndNewlines)
            .replacingOccurrences(of: ",", with: ".")
        guard let value = Double(normalized), value.isFinite, value >= 0 else { return nil }
        return value
    }

    private var result: (remaining: Double, percentage: Double)? {
        guard let incomeValue = amount(income), incomeValue > 0,
              let expensesValue = amount(expenses),
              let rentValue = amount(rent) else { return nil }
        return (incomeValue - expensesValue - rentValue, rentValue / incomeValue * 100)
    }

    var body: some View {
        NavigationStack {
            Form {
                Section {
                    LabeledContent("الدخل الشهري الصافي") {
                        TextField("€", text: $income)
                            .keyboardType(.decimalPad)
                            .multilineTextAlignment(.trailing)
                            .accessibilityIdentifier("budget.income")
                    }
                    LabeledContent("المصاريف الشهرية الأخرى") {
                        TextField("€", text: $expenses)
                            .keyboardType(.decimalPad)
                            .multilineTextAlignment(.trailing)
                            .accessibilityIdentifier("budget.expenses")
                    }
                    LabeledContent("إيجار الشقة") {
                        TextField("€", text: $rent)
                            .keyboardType(.decimalPad)
                            .multilineTextAlignment(.trailing)
                            .accessibilityIdentifier("budget.rent")
                    }
                } header: {
                    Text("المبالغ الشهرية")
                } footer: {
                    Text("أدخل مبالغك الفعلية. لا تُرسل هذه الأرقام إلى الخادم.")
                }

                if let result {
                    Section("الحساب") {
                        LabeledContent("المتبقي بعد الإيجار والمصاريف") {
                            Text(result.remaining, format: .currency(code: "EUR"))
                                .font(.headline)
                        }
                        LabeledContent("نسبة الإيجار من الدخل") {
                            Text(result.percentage / 100, format: .percent.precision(.fractionLength(1)))
                        }
                    }
                }
            }
            .scrollDismissesKeyboard(.interactively)
            .navigationTitle("ميزانية الإيجار")
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .topBarTrailing) {
                    Button("إغلاق", action: { dismiss() })
                }
            }
            .accessibilityIdentifier("budget.screen")
        }
    }
}
