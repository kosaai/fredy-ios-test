import SwiftUI

@MainActor
struct SearchFilterChips: View {
    let jobs: [SearchJob]
    @Binding var selectedJobID: String?
    @Binding var selectedRegion: String?

    private var regions: [String] { Set(jobs.compactMap(\.regionLabel)).sorted() }

    var body: some View {
        VStack(alignment: .leading, spacing: 8) {
            ScrollView(.horizontal) {
                HStack(spacing: 8) {
                    Button {
                        selectedJobID = nil
                        selectedRegion = nil
                    } label: {
                        Label("jobs.all_searches", systemImage: selectedJobID == nil && selectedRegion == nil ? "checkmark.circle.fill" : "circle")
                    }
                    ForEach(jobs) { job in
                        Button {
                            selectedRegion = nil
                            selectedJobID = job.id
                        } label: {
                            HStack(spacing: 6) {
                                Image(systemName: selectedJobID == job.id ? "checkmark.circle.fill" : "circle")
                                Text(job.name ?? String(localized: "jobs.untitled", locale: Locale(identifier: "ar")))
                                if let count = job.numberOfFoundListings {
                                    Text(count, format: .number.locale(Locale(identifier: "ar")))
                                    Text("jobs.active_short")
                                } else {
                                    Text("jobs.unavailable")
                                }
                            }
                        }
                    }
                }
                .buttonStyle(.bordered)
                .frame(minHeight: 44)
            }
            if !regions.isEmpty {
                Text("jobs.region_from_url").font(.caption).foregroundStyle(.secondary)
                ScrollView(.horizontal) {
                    HStack(spacing: 8) {
                        ForEach(regions, id: \.self) { region in
                            Button {
                                selectedJobID = nil
                                selectedRegion = selectedRegion == region ? nil : region
                            } label: {
                                HStack {
                                    Image(systemName: selectedRegion == region ? "checkmark.circle.fill" : "circle")
                                    Text(verbatim: region)
                                }
                            }
                        }
                    }
                    .buttonStyle(.bordered)
                    .frame(minHeight: 44)
                }
            }
            Text("jobs.active_count_note")
                .font(.caption)
                .foregroundStyle(.secondary)
                .fixedSize(horizontal: false, vertical: true)
        }
    }
}
