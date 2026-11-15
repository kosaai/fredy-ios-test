"""Dashboard regression gates; optional execution of the actual Foundation DTO, no network or live fixtures."""
from pathlib import Path
import os
import shutil
import subprocess
import tempfile
import unittest

ROOT = Path(__file__).resolve().parents[1]
def source(path): return (ROOT / path).read_text()
def dashboard_source():
    return source('Sources/Shared/Listings/RentalListing.swift').split('struct FindHausDashboardSnapshot:', 1)[1].split('\n@MainActor\nprotocol FredyDashboardServing', 1)[0]

# Unit decoder inputs only; never runtime app defaults or claimed server responses.
SWIFT_CHECKS = r'''
func decodeInterval(_ literal: String) throws -> FindHausDashboardSnapshot {
    let json = "{\"general\":{\"interval\":\(literal)},\"trend\":{\"perDay\":[{\"count\":7}]}}"
    return try JSONDecoder().decode(FindHausDashboardSnapshot.self, from: Data(json.utf8))
}
for (literal, expected) in [("15", 15.0), ("15.5", 15.5), ("1e2", 100.0),
                            ("\"15\"", 15.0), ("\"15.5\"", 15.5), ("\"1e2\"", 100.0),
                            ("\" 15 \"", 15.0), ("\"+15\"", 15.0), ("0.25", 0.25)] {
    let value = try decodeInterval(literal)
    precondition(value.general?.interval == expected, "Valid interval rejected or changed")
    precondition(value.newToday == 7, "Valid dashboard counts were lost")
}
for literal in ["0", "-1", "true", "false", "[]", "{}", "\"\"", "\"   \"", "\"abc\"",
                "\"NaN\"", "\"Infinity\"", "\"-Infinity\"", "\"0\"", "\"-1\"", "\"0x1p2\"",
                "\"1,5\"", "1e300", "\"1e300\"", "\(Double(Int.max))"] {
    do {
        _ = try decodeInterval(literal)
        fatalError("Invalid interval accepted: \(literal)")
    } catch is DecodingError { }
}
for json in ["{\"general\":{}}", "{\"general\":{\"interval\":null}}", "{}"] {
    let value = try JSONDecoder().decode(FindHausDashboardSnapshot.self, from: Data(json.utf8))
    precondition(value.general?.interval == nil, "Unknown interval became zero")
    precondition(value.intervalMinutes == nil, "Unknown schedule became zero")
}
let fractional = try decodeInterval("0.25")
precondition(fractional.intervalMinutes == nil, "Subminute interval displayed as zero minutes")
for field in ["lastRun", "nextRun"] {
    let json = "{\"general\":{\"interval\":\"15\",\"\(field)\":\"invalid\"}}"
    do {
        _ = try JSONDecoder().decode(FindHausDashboardSnapshot.self, from: Data(json.utf8))
        fatalError("Unrelated date decoding was relaxed")
    } catch is DecodingError { }
}
print("ACTUAL_DASHBOARD_DTO_REGRESSIONS_PASS")
'''

class DashboardDecodingContracts(unittest.TestCase):
    def test_interval_explicit_decoder_accepts_numbers_and_decimal_strings_without_zero_fallback(self):
        text = dashboard_source().split('struct Trend:', 1)[0]
        for token in ['init(from decoder: Decoder) throws', 'case interval, lastRun, nextRun', 'decodeNil(forKey: .interval)', 'decode(Double.self, forKey: .interval)', 'decode(String.self, forKey: .interval)', 'trimmingCharacters(in: .whitespacesAndNewlines)', '.regularExpression', 'value.isFinite', 'value > 0', 'value < Double(Int.max)', 'interval = value', 'DecodingError.dataCorruptedError', 'decodeIfPresent(Double.self, forKey: .lastRun)', 'decodeIfPresent(Double.self, forKey: .nextRun)']:
            self.assertIn(token, text)
        self.assertNotIn('?? 0', text)
        self.assertNotIn('interval = 0', text)
        self.assertIn('interval >= 1, interval < Double(Int.max)', dashboard_source())

    @unittest.skipUnless(shutil.which('swift'), 'Swift unavailable: actual Foundation decoder vectors not executed; source gates are not runtime proof')
    def test_actual_foundation_dashboard_dto_regression_vectors(self):
        script = 'import Foundation\nstruct FindHausDashboardSnapshot:' + dashboard_source() + '\n' + SWIFT_CHECKS
        scratch = os.environ.get('TMPDIR', str(Path.home() / '.hermes/cache/scratch'))
        with tempfile.TemporaryDirectory(prefix='findhaus-dashboard-swift-', dir=scratch) as d:
            p = Path(d) / 'DashboardRegression.swift'
            p.write_text(script)
            result = subprocess.run([shutil.which('swift'), str(p)], text=True, capture_output=True, timeout=120)
            self.assertEqual(result.returncode, 0, result.stdout + result.stderr)
            self.assertIn('ACTUAL_DASHBOARD_DTO_REGRESSIONS_PASS', result.stdout)

    def test_dashboard_decoder_error_is_typed_without_wrapping_http_or_logging_payloads(self):
        text = source('Sources/Shared/Authentication/FredyAuthService.swift')
        body = text.split('func fetchDashboardSnapshot()', 1)[1].split('func startAllSearches()', 1)[0]
        self.assertIn('catch is DecodingError', body)
        self.assertIn('throw ListingsFailure.dashboardDecoding', body)
        self.assertIn('guard response.mimeType == "application/json"', body)
        self.assertLess(body.index('authenticatedRead('), body.index('do {'))
        self.assertNotIn('try? JSONDecoder()', body)
        for token in ['print(', 'debugPrint(', 'String(data:', 'localizedDescription', 'URLSession(']:
            self.assertNotIn(token, body)
        self.assertIn('case dashboardDecoding', source('Sources/Shared/Listings/RentalListing.swift'))

    def test_home_separates_decoding_http_access_rate_limit_and_network_messages(self):
        home = source('Sources/Features/Home/HomeView.swift')
        body = home.split('private var dashboardError:', 1)[1].split('@State', 1)[0]
        for token in ['guard case .failed(let failure)', 'case .dashboardDecoding:', 'case .server:', 'case .accessDenied:', 'case .rateLimited:', 'case .network:', 'case .invalidResponse:', 'case .sessionExpired: return nil', 'تحليل بيانات الإحصاءات', '(HTTP)']:
            self.assertIn(token, body)
        self.assertNotIn('localizedDescription', body)
        self.assertNotIn('print(', body)
        self.assertIn('case .invalidResponse, .dashboardDecoding:', source('Sources/Features/Jobs/JobsModel.swift'))
        coordinator = source('Sources/App/AppDataModel.swift')
        self.assertLess(coordinator.index('await home.loadInitialIfNeeded()'), coordinator.index('await loadDashboard()'))
        self.assertIn('dashboardState = .failed(failure)', coordinator)

if __name__ == '__main__': unittest.main(verbosity=2)
