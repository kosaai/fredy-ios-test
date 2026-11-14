import SwiftUI
import MapKit

/// Native cartography. No property markers are invented: the current listing
/// contract does not expose coordinates, so those must be integrated separately.
struct RentalMapView: View {
    @State private var camera: MapCameraPosition = .region(
        MKCoordinateRegion(
            center: CLLocationCoordinate2D(latitude: 51.1657, longitude: 10.4515),
            span: MKCoordinateSpan(latitudeDelta: 6.5, longitudeDelta: 8.0)
        )
    )

    var body: some View {
        ZStack(alignment: .top) {
            Map(position: $camera)
                .mapControlVisibility(.visible)
                .ignoresSafeArea(edges: .bottom)

            VStack(alignment: .leading, spacing: 8) {
                Label("خريطة العقارات", systemImage: "map.fill")
                    .font(.headline)
                Text("ستظهر مواقع الإعلانات عندما تتوفر إحداثيات فعلية في بيانات Fredy.")
                    .font(.footnote)
                    .foregroundStyle(.secondary)
                    .fixedSize(horizontal: false, vertical: true)
            }
            .frame(maxWidth: .infinity, alignment: .leading)
            .padding(16)
            .background(.regularMaterial, in: RoundedRectangle(cornerRadius: 19))
            .padding(16)
        }
        .navigationTitle("الخريطة")
        .navigationBarTitleDisplayMode(.inline)
        .accessibilityIdentifier("map.screen")
    }
}
