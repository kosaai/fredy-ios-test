import SwiftUI

@MainActor
struct JobManagementView: View {
    @Bindable var model: JobManagementModel
    @Environment(\.dismiss) private var dismiss
    @State private var confirming = false

    var body: some View {
        NavigationStack {
            Form {
                if let baseline = model.sourceBaseline {
                    Section("اسم البحث") { TextField("اسم البحث", text: $model.name) }
                        .disabled(model.phase != .ready)
                    Section("روابط المزوّدين المحفوظة") {
                        ForEach(Array(model.providers.indices), id: \.self) { index in
                            VStack(alignment: .leading, spacing: 8) {
                                Text(model.providers[index]["id"].stringValue ?? "هوية غير معروفة")
                                    .font(.caption.monospaced())
                                TextField("رابط البحث", text: url(index), axis: .vertical)
                                    .keyboardType(.URL)
                                    .textInputAutocapitalization(.never)
                                    .autocorrectionDisabled()
                                    .environment(\.layoutDirection, .leftToRight)
                            }
                        }
                        Text("تُعدّل الروابط الموجودة فقط. تظل هويات المزوّدين وترتيبهم وخياراتهم الأخرى كما قُرئت، ويتحقق الخادم من توافق الرابط مع المزوّد.")
                            .font(.footnote)
                    }
                    .disabled(model.phase != .ready)
                    Section("إعدادات تُحفظ دون تغيير") {
                        if let count = baseline["shareWithUsers"].arrayValue?.count {
                            LabeledContent("مشاركات البحث", value: String(count))
                        }
                        if let count = baseline["notificationAdapter"].arrayValue?.count {
                            LabeledContent("مراجع القنوات المحفوظة", value: String(count))
                        }
                        Text("القائمة السوداء والمواقع المستبعدة والمرشحات المكانية والمواصفات والتنقل ونوع الصفقة تُحفظ كاملة. لا تُنسخ الإعلانات ولا يتغير مالك المهمة الأصلية.")
                        if model.duplicate {
                            Text("ستُنشأ مهمة بهوية جديدة، متوقفة عن الجدولة، بنفس إعدادات ومشاركات الأصل. لا يُرسل تشغيل أو تنبيه. مالك النسخة هو الحساب الذي ينشئها.")
                        } else {
                            Text("تبقى حالة الجدولة كما هي. يلزم أن تكون المهمة غير قيد التشغيل؛ أوقف الجدولة أولًا إذا كانت المهمة مفعّلة ومرتبطة بقنوات تنبيه.")
                        }
                    }
                    Section {
                        Button(model.duplicate ? "إنشاء نسخة متوقفة" : "حفظ التعديلات") { confirming = true }
                            .disabled(!model.canSave)
                    }
                }
                Section {
                    if model.busy { ProgressView("جارٍ التحقق…") }
                    if let notice = model.notice { Text(notice) }
                    if model.phase == .uncertain {
                        Button("التحقق من نفس الطلب دون تكرار") { Task { await model.reconcile() } }
                    } else if model.phase == .failed {
                        Button("إعادة تحميل مسودة حديثة") { Task { await model.reloadDraft() } }
                    }
                }
            }
            .navigationTitle(model.duplicate ? "نسخ البحث" : "تعديل البحث")
            .navigationBarTitleDisplayMode(.inline)
            .toolbar { ToolbarItem(placement: .topBarTrailing) {
                Button("إغلاق") { dismiss() }.disabled(model.busy)
            } }
            .task { await model.loadIfNeeded() }
            .interactiveDismissDisabled(model.busy)
            .confirmationDialog("تأكيد حفظ البحث؟", isPresented: $confirming, titleVisibility: .visible) {
                Button(model.duplicate ? "إنشاء النسخة والتحقق" : "حفظ والتحقق") { model.save() }
                Button("إلغاء", role: .cancel) {}
            } message: {
                Text("تُقرأ أحدث إعدادات الأصل قبل إرسال طلب واحد، ثم تُراجع الهوية والحقول المحفوظة. لا نعيد POST تلقائيًا عند فقد الرد، ولا نحذف شيئًا كاسترجاع.")
            }
        }
        .environment(\.layoutDirection, .rightToLeft)
        .accessibilityIdentifier("jobs.management")
    }

    private func url(_ index: Int) -> Binding<String> {
        Binding(get: { model.providers.indices.contains(index) ? model.providers[index]["url"].stringValue ?? "" : "" }, set: { value in
            guard model.providers.indices.contains(index) else { return }
            model.providers[index]["url"] = .string(value)
        })
    }
}
