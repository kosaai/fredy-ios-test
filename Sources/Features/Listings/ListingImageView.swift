import SwiftUI
import UIKit
import ImageIO

@MainActor
final class ListingImageLoader {
    private let service: any FredyListingsServing
    private let cache = NSCache<NSString, UIImage>()
    private var cacheGeneration = 0
    private var requests: [String: Task<Data, Error>] = [:]

    init(service: any FredyListingsServing) {
        self.service = service
        cache.countLimit = 40
        cache.totalCostLimit = 16 * 1024 * 1024
    }

    func image(for id: String) async throws -> UIImage {
        try Task.checkCancellation()
        if let image = cache.object(forKey: id as NSString) { return image }
        let generation = cacheGeneration
        let request: Task<Data, Error>
        if let pending = requests[id] { request = pending }
        else {
            request = Task { try await service.fetchListingImage(id: id) }
            requests[id] = request
        }
        defer { if cacheGeneration == generation { requests[id] = nil } }
        let data = try await request.value
        try Task.checkCancellation()
        guard cacheGeneration == generation else { throw CancellationError() }
        if let image = cache.object(forKey: id as NSString) { return image }
        let options: [CFString: Any] = [
            kCGImageSourceCreateThumbnailFromImageAlways: true,
            kCGImageSourceCreateThumbnailWithTransform: true,
            kCGImageSourceThumbnailMaxPixelSize: 640
        ]
        guard let source = CGImageSourceCreateWithData(data as CFData, nil),
              let cgImage = CGImageSourceCreateThumbnailAtIndex(source, 0, options as CFDictionary) else {
            throw ListingsFailure.imageUnavailable
        }
        let image = UIImage(cgImage: cgImage)
        cache.setObject(image, forKey: id as NSString, cost: cgImage.bytesPerRow * cgImage.height)
        return image
    }

    func clear() {
        cacheGeneration += 1
        requests.values.forEach { $0.cancel() }
        requests.removeAll()
        cache.removeAllObjects()
    }
}

@MainActor
struct ListingImageView: View {
    let listingID: String
    let loader: ListingImageLoader
    let onSessionExpired: () -> Void
    // The same authenticated thumbnail loader supports a compact square card.
    var thumbnailSize: CGFloat = 116
    @State private var image: UIImage?
    @State private var failure: ListingsFailure?
    @State private var retry = 0

    var body: some View {
        Group {
            if let image {
                Image(uiImage: image)
                    .resizable()
                    .scaledToFill()
                    .frame(width: thumbnailSize, height: thumbnailSize)
                    .clipped()
                    .accessibilityLabel(Text("listings.main_image"))
            } else if let failure {
                VStack {
                    Image(systemName: "photo").accessibilityHidden(true)
                    Text(LocalizedStringKey(failure.localizationKey))
                        .font(.caption)
                        .multilineTextAlignment(.center)
                    Button("listings.retry_image") { retry += 1 }
                        .frame(minHeight: 44)
                        .buttonStyle(.bordered)
                }
            } else {
                ProgressView("listings.image_loading")
            }
        }
        .frame(width: thumbnailSize, height: thumbnailSize)
        .clipped()
        .task(id: "\(listingID):\(retry)") {
            image = nil
            failure = nil
            do {
                let loaded = try await loader.image(for: listingID)
                try Task.checkCancellation()
                image = loaded
            } catch is CancellationError {
                return
            } catch let error as ListingsFailure {
                if error == .sessionExpired { onSessionExpired() }
                else { failure = error }
            } catch {
                failure = .imageUnavailable
            }
        }
    }
}
