"""Offline source invariants, not Swift runtime or authenticated API tests."""
from pathlib import Path
import unittest

ROOT = Path(__file__).resolve().parents[1]


class ListingsSourceContract(unittest.TestCase):
    def test_native_screen_paginates_and_routes_expiry_with_authenticated_images(self):
        names = ['ListingsModel.swift', 'ListingsView.swift', 'ListingRow.swift', 'ListingImageView.swift']
        paths = [ROOT / 'Sources/Features/Listings' / n for n in names]
        self.assertTrue(all(p.exists() for p in paths), 'Listings screen/state/image path is missing')
        model, view, row, image = [p.read_text() for p in paths]
        for required in ['@Observable', '@MainActor', 'case sessionExpired', 'guard !isLoading', 'response.page == requestedPage', 'lastPage + 1', 'seen.insert', '.filter(\\.isRental)', 'response.totalNumber', 'response.result.isEmpty', 'images.clear()', 'Task.checkCancellation()']:
            self.assertIn(required, model)
        for required in ['.task', '.refreshable', 'ForEach', 'loadNextPage', '.failed', '.sessionExpired', 'model.items.isEmpty', 'onSessionExpired']:
            self.assertIn(required, view)
        for required in ['listing.title', 'listing.address', 'listing.euroPrice', 'listing.size', 'listing.rooms', '.currency(code: "EUR")', 'm²', 'ListingImageView']:
            self.assertIn(required, row)
        for required in ['fetchListingImage', 'NSCache', 'cacheGeneration == generation', 'kCGImageSourceThumbnailMaxPixelSize', 'Task.checkCancellation()', 'retry', '.sessionExpired']:
            self.assertIn(required, image)
        root = (ROOT / 'Sources/App/AppRootView.swift').read_text()
        self.assertIn('AuthenticatedTabs(service: model.service', root)
        self.assertIn('ListingsView(service: service', (ROOT / 'Sources/App/AuthenticatedTabs.swift').read_text())
        self.assertIn('model.returnToLogin()', root)
        self.assertNotIn('URLSession(', root)
        for source in [model, view, row, image]:
            for forbidden in ['AsyncImage', 'URLSession(', 'URLSession.shared', 'https://', 'UserDefaults', 'print(', 'debugPrint(']:
                self.assertNotIn(forbidden, source)

    def test_authenticated_reads_reuse_login_session_and_reject_stale_results(self):
        source = (ROOT / 'Sources/Shared/Authentication/FredyAuthService.swift').read_text()
        self.assertIn('func fetchListings(', source, 'Authenticated listing reads are missing')
        for required in ['FredyClientServing', 'api/listings/table', 'URLQueryItem(name: "page"', 'URLQueryItem(name: "pageSize"', 'func fetchListingImage(', 'accept: "image/*"', 'sessionGeneration', 'generation == sessionGeneration', 'sessionVerified', 'throw ListingsFailure.sessionExpired', 'response.statusCode == 401']:
            self.assertIn(required, source)
        self.assertTrue('case 404: throw accept == "image/*" ? ListingsFailure.imageUnavailable : .server' in source, 'A missing table must not be reported as a missing image')
        self.assertEqual(source.count('URLSession('), 1)
        self.assertIn('session.data(for: request)', source)
        for forbidden in ['URLSession.shared', 'HTTPCookieStorage.shared', 'AsyncImage', '/details', 'URL(string: id)']:
            self.assertNotIn(forbidden, source)

    def test_real_fredy_listing_actions_use_verified_session_and_safe_removal(self):
        service = (ROOT / 'Sources/Shared/Authentication/FredyAuthService.swift').read_text()
        dto = (ROOT / 'Sources/Shared/Listings/RentalListing.swift').read_text()
        row = (ROOT / 'Sources/Features/Listings/ListingRow.swift').read_text()
        home = (ROOT / 'Sources/Features/Home/HomeView.swift').read_text()
        listings = (ROOT / 'Sources/Features/Listings/ListingsView.swift').read_text()

        for action in ['toggleListingWatch', 'setListingStatus',
                       'fetchListingApplication', 'softRemoveListing']:
            self.assertIn('func ' + action + '(', service)
            self.assertIn('func ' + action + '(', dto)
        for route in ['api/listings/watch', 'api/listings/\\(id)/status',
                      'api/listings/\\(id)/application', 'api/listings/']:
            self.assertIn(route, service)
        self.assertIn('authenticatedWrite(path: "api/listings/", body: body, method: "DELETE")', service)
        self.assertIn('"hardDelete": false', service)
        self.assertIn('guard sessionVerified else', service)
        self.assertIn('URLSessionConfiguration.ephemeral', service)

        for name in ['isWatched', 'status', 'published_at', 'created_at', 'link',
                     'provider', 'ListingApplicationDraft']:
            self.assertIn(name, dto)
        for name in ['"star.fill"', '"star"', '"listing.watch"',
                     '"listing.status"', '"listing.application"',
                     '"listing.external_link"', '"listing.more"',
                     'showingLetter', 'confirmingRemoval', 'UIPasteboard.general.string',
                     'onChanged()', 'Button("مقبول")', 'Button("مرفوض")']:
            self.assertIn(name, row)
        self.assertLess(row.index('UIPasteboard.general.string = letterText'),
                        row.index('try await actions.setListingStatus(id: listingID, status: "applied")'))
        for forbidden in ['heart', 'favorite', 'hardDelete": true',
                          'URLSession(', 'https://', 'UserDefaults']:
            self.assertNotIn(forbidden, row)
        for source in [home, listings]:
            self.assertIn('actions: listingActions', source)
            self.assertIn('onChanged:', source)
            self.assertIn('await model.reload()', source)

    def test_real_nullable_listing_contract(self):
        path = ROOT / 'Sources/Shared/Listings/RentalListing.swift'
        self.assertTrue(path.exists(), 'Actual Fredy listing DTO is missing')
        source = path.read_text()
        for required in ['totalNumber', 'page', 'result', 'let id: String', 'let title: String?', 'let address: String?', 'let price: Double?', 'let size: Double?', 'let rooms: Double?', 'let currency: String?', 'let dealType: String?', 'decodeIfPresent', '.isFinite', '== "rent"', '== "EUR"']:
            self.assertIn(required, source)
        for invented in ['coldRent', 'warmRent', 'livingSpace', 'numberOfRooms', 'UUID()', 'city: String']:
            self.assertNotIn(invented, source)


if __name__ == '__main__':
    unittest.main(verbosity=2)
