import SwiftUI
import MapKit

@MainActor
struct RentalMapView: View {
    let data: AppDataModel
    let jobsModel: JobsModel
    let actions: any FredyListingActionServing
    let onSessionExpired: () -> Void
    @State private var camera: MapCameraPosition = .automatic
    @State private var selectedPin: String?
    private var model: RentalMapModel { data.map }
    private struct Selection: Identifiable { let id: String }

    var body: some View {
        Map(position: $camera, selection: $selectedPin) {
            ForEach(model.items) { listing in
                if let latitude = listing.latitude, let longitude = listing.longitude {
                    Marker(listing.title ?? "إعلان إيجار",
                           coordinate: CLLocationCoordinate2D(latitude: latitude, longitude: longitude))
                        .tag(listing.id)
                        .tint(Color.accentColor)
                }
            }
        }
        .mapControlVisibility(.visible)
        .ignoresSafeArea(edges: .bottom)
        .safeAreaInset(edge: .top) { mapStatus }
        .navigationTitle("الخريطة")
        .navigationBarTitleDisplayMode(.inline)
        .accessibilityIdentifier("map.screen")
        .task { await data.loadMap() }
        .onChange(of: selectedPin) { _, id in
            if let id { model.selectListing(id: id) }
        }
        .onChange(of: model.selectedID) { _, id in
            if id == nil { selectedPin = nil }
        }
        .sheet(item: Binding(
            get: { model.selectedID.map { Selection(id: $0) } },
            set: { if $0 == nil { model.dismissSelection(); selectedPin = nil } }
        )) { selection in
            NavigationStack {
                ScrollView {
                    VStack(alignment: .leading, spacing: 16) {
                        if let listing = model.detail, model.detailState == .ready {
                            ListingRow(listing: listing, images: data.home.images, actions: actions,
                                       onChanged: { data.scheduleRefresh(jobs: jobsModel) }, onSessionExpired: onSessionExpired)
                            if let description = listing.description {
                                Text(description).textSelection(.enabled)
                            }
                        } else if case .failed(let failure) = model.detailState {
                            Label(LocalizedStringKey(failure.localizationKey), systemImage: "exclamationmark.triangle")
                            Button("listings.retry") { model.selectListing(id: selection.id) }
                        } else {
                            ProgressView("listings.loading")
                        }
                    }
                    .padding()
                }
                .navigationTitle("تفاصيل الإعلان")
                .navigationBarTitleDisplayMode(.inline)
                .toolbar {
                    ToolbarItem(placement: .topBarTrailing) {
                        Button("إغلاق") { model.dismissSelection() }
                    }
                }
            }
            .presentationDetents([.medium, .large])
        }
    }

    private var mapStatus: some View {
        VStack(alignment: .leading, spacing: 8) {
            HStack {
                Label("خريطة العقارات", systemImage: "map.fill").font(.headline)
                Spacer()
                Button {
                    Task { await data.refresh(jobs: jobsModel, force: true) }
                } label: {
                    Label("تحديث", systemImage: "arrow.clockwise").frame(minHeight: 44)
                }
                .disabled(model.state == .loading)
                .accessibilityIdentifier("map.refresh")
            }
            if model.state == .loading || model.state == .idle {
                ProgressView("listings.loading")
            } else if case .failed(let failure) = model.state {
                Label(LocalizedStringKey(failure.localizationKey), systemImage: "exclamationmark.triangle")
            } else if model.items.isEmpty {
                Text("لا توجد إعلانات إيجار نشطة بإحداثيات صالحة في نطاق البحث المحدد.")
            } else {
                Text("\(model.items.count) موقع محفوظ من Fredy. اضغط علامة لعرض الإعلان.")
            }
            Text("الخريطة تعرض الإعلانات النشطة ذات الإحداثيات المخزنة فقط؛ غياب موقع لا يعني غياب الإعلان. فلاتر النص والسعر والغرف تخص قائمة الإعلانات المحمّلة، ولا تُطبّق هنا.")
                .font(.caption)
                .foregroundStyle(.secondary)
        }
        .font(.footnote)
        .frame(maxWidth: .infinity, alignment: .leading)
        .padding(14)
        .background(.regularMaterial, in: RoundedRectangle(cornerRadius: 19))
        .padding(.horizontal, 16)
    }
}
