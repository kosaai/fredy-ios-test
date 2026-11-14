import SwiftUI

@MainActor
struct ListingRow: View {
    let listing: RentalListing
    let images: ListingImageLoader
    let onSessionExpired: () -> Void

    var body: some View {
        VStack(alignment: .leading, spacing: 0) {
            ListingImageView(listingID: listing.id, loader: images,
                             onSessionExpired: onSessionExpired)
                .frame(maxWidth: .infinity)
                .frame(height: 202)
                .clipped()

            VStack(alignment: .leading, spacing: 11) {
                HStack(alignment: .firstTextBaseline) {
                    if let price = listing.euroPrice {
                        Text(price, format: .currency(code: "EUR"))
                            .font(.system(size: 25, weight: .bold, design: .rounded))
                    } else {
                        Text("listings.unavailable")
                            .font(.headline)
                            .foregroundStyle(.secondary)
                    }
                    Spacer(minLength: 8)
                    if let jobName = listing.jobName {
                        Text(jobName)
                            .font(.caption2)
                            .lineLimit(1)
                            .padding(.horizontal, 9)
                            .padding(.vertical, 6)
                            .background(Color(uiColor: .tertiarySystemGroupedBackground),
                                        in: Capsule())
                    }
                }
                Text(listing.title ?? String(localized: "listings.untitled",
                                             locale: Locale(identifier: "ar")))
                    .font(.headline)
                    .multilineTextAlignment(.leading)
                    .fixedSize(horizontal: false, vertical: true)

                Label {
                    Text(listing.address ?? String(localized: "listings.unavailable",
                                                   locale: Locale(identifier: "ar")))
                        .lineLimit(3)
                } icon: {
                    Image(systemName: "mappin.and.ellipse")
                }
                .font(.subheadline)
                .foregroundStyle(.secondary)

                HStack(spacing: 18) {
                    Label {
                        if let size = listing.size {
                            Text(size.formatted(.number.locale(Locale(identifier: "ar"))) + " m²")
                        } else {
                            Text("listings.unavailable")
                        }
                    } icon: { Image(systemName: "square.dashed") }

                    Label {
                        if let rooms = listing.rooms {
                            Text(rooms, format: .number.locale(Locale(identifier: "ar")))
                        } else {
                            Text("listings.unavailable")
                        }
                    } icon: { Image(systemName: "door.left.hand.closed") }
                }
                .font(.caption)
                .foregroundStyle(.secondary)
            }
            .padding(17)
        }
        .frame(maxWidth: .infinity, alignment: .leading)
        .background(Color(uiColor: .secondarySystemGroupedBackground))
        .clipShape(RoundedRectangle(cornerRadius: 22))
        .accessibilityElement(children: .contain)
    }
}
