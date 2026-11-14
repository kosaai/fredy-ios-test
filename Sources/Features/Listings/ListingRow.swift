import SwiftUI

/// Compact rental card shared by the Home and Listings screens.
/// All values and images come from the authenticated Fredy listing response.
/// Only fields provided by the authenticated listing response are rendered.
@MainActor
struct ListingRow: View {
    let listing: RentalListing
    let images: ListingImageLoader
    let onSessionExpired: () -> Void

    private let photoSide: CGFloat = 116

    var body: some View {
        HStack(alignment: .top, spacing: 13) {
            VStack(alignment: .leading, spacing: 9) {
                Text(listing.title ?? String(localized: "listings.untitled",
                                             locale: Locale(identifier: "ar")))
                    .font(.system(size: 15, weight: .semibold))
                    .foregroundStyle(.primary)
                    .lineLimit(2)
                    .multilineTextAlignment(.leading)
                    .frame(maxWidth: .infinity, alignment: .leading)

                if let address = listing.address {
                    Text(address)
                        .font(.system(size: 12))
                        .foregroundStyle(.secondary)
                        .lineLimit(2)
                        .frame(maxWidth: .infinity, alignment: .leading)
                }

                if let price = listing.euroPrice {
                    Text(price, format: .currency(code: "EUR"))
                        .font(.system(size: 17, weight: .bold, design: .rounded))
                        .foregroundStyle(Color(red: 0.14, green: 0.47, blue: 0.34))
                        .lineLimit(1)
                        .minimumScaleFactor(0.75)
                        .frame(maxWidth: .infinity, alignment: .leading)
                } else {
                    Text("listings.unavailable")
                        .font(.footnote)
                        .foregroundStyle(.secondary)
                }

                HStack(spacing: 13) {
                    if let rooms = listing.rooms {
                        Label {
                            Text(rooms, format: .number.locale(Locale(identifier: "ar")))
                        } icon: {
                            Image(systemName: "door.left.hand.closed")
                        }
                    }

                    if let size = listing.size {
                        Label {
                            Text(size, format: .number.locale(Locale(identifier: "ar")))
                            + Text(" m²")
                        } icon: {
                            Image(systemName: "square.dashed")
                        }
                    }
                }
                .font(.system(size: 11, weight: .medium))
                .foregroundStyle(.secondary)
                .lineLimit(1)
                .minimumScaleFactor(0.8)
                .frame(maxWidth: .infinity, alignment: .leading)
            }
            .frame(maxWidth: .infinity, alignment: .leading)

            ListingImageView(listingID: listing.id, loader: images,
                             onSessionExpired: onSessionExpired,
                             thumbnailSize: photoSide)
                .frame(width: photoSide, height: photoSide)
                .background(Color(uiColor: .tertiarySystemGroupedBackground))
                .clipShape(RoundedRectangle(cornerRadius: 14))
                .accessibilityIdentifier("listings.thumbnail")
        }
        .padding(12)
        .frame(maxWidth: .infinity, alignment: .topLeading)
        .background(
            Color(uiColor: .secondarySystemGroupedBackground),
            in: RoundedRectangle(cornerRadius: 19)
        )
        .overlay {
            RoundedRectangle(cornerRadius: 19)
                .strokeBorder(Color(uiColor: .separator).opacity(0.18), lineWidth: 0.5)
        }
        .accessibilityElement(children: .contain)
        .accessibilityIdentifier("listings.row.horizontal")
    }
}
