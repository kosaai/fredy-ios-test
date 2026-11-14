import SwiftUI

@MainActor
struct ListingRow: View {
    let listing: RentalListing
    let images: ListingImageLoader
    let onSessionExpired: () -> Void

    var body: some View {
        VStack(alignment: .leading, spacing: 12) {
            Text(listing.title ?? String(localized: "listings.untitled", locale: Locale(identifier: "ar")))
                .font(.headline)
                .fixedSize(horizontal: false, vertical: true)
            ListingImageView(listingID: listing.id, loader: images, onSessionExpired: onSessionExpired)
            LabeledContent("listings.price") {
                if let price = listing.euroPrice {
                    Text(price, format: .currency(code: "EUR").locale(Locale(identifier: "ar")))
                } else {
                    Text("listings.unavailable")
                }
            }
            LabeledContent("listings.location") {
                Text(listing.address ?? String(localized: "listings.unavailable", locale: Locale(identifier: "ar")))
                    .fixedSize(horizontal: false, vertical: true)
            }
            LabeledContent("listings.area") {
                if let size = listing.size {
                    Text(size.formatted(.number.locale(Locale(identifier: "ar"))) + " m²")
                } else {
                    Text("listings.unavailable")
                }
            }
            LabeledContent("listings.rooms") {
                if let rooms = listing.rooms {
                    Text(rooms, format: .number.locale(Locale(identifier: "ar")))
                } else {
                    Text("listings.unavailable")
                }
            }
        }
        .padding(.vertical, 8)
    }
}
