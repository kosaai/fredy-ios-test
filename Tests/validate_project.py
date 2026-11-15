"""Offline scaffold checks, not a substitute for an Xcode build/UI run.

Optional parsers (installed outside this project):
  python -m pip install tree-sitter tree-sitter-swift openstep-parser
Run: python Tests/validate_project.py
"""
import json
import hashlib
import struct
from pathlib import Path
import re
import unittest
import xml.etree.ElementTree as ET

ROOT = Path(__file__).resolve().parents[1]


class NativeProjectChecks(unittest.TestCase):
    def test_rentals_use_compact_horizontal_cards_without_favorites(self):
        card = (ROOT / "Sources/Features/Listings/ListingRow.swift").read_text()
        image = (ROOT / "Sources/Features/Listings/ListingImageView.swift").read_text()
        home = (ROOT / "Sources/Features/Home/HomeView.swift").read_text()
        listings = (ROOT / "Sources/Features/Listings/ListingsView.swift").read_text()
        self.assertIn("HStack(alignment: .top, spacing: 13)", card)
        self.assertIn("thumbnailSize: photoSide", card)
        self.assertIn("listings.row.horizontal", card)
        self.assertIn("listing.euroPrice", card)
        self.assertIn("listing.rooms", card)
        self.assertIn("listing.size", card)
        self.assertIn("listing.address", card)
        self.assertIn("thumbnailSize: CGFloat = 116", image)
        self.assertIn("ListingRow(", home)
        self.assertIn("ListingRow(", listings)
        for unwanted in ["heart", "favorite", "bathroom", "sample", "mock"]:
            self.assertNotIn(unwanted, card.lower())

    def test_settings_use_vertical_native_navigation(self):
        settings = (ROOT / "Sources/Features/Settings/RentalSettingsView.swift").read_text()
        self.assertIn("NavigationStack(path: $navigationPath)", settings)
        self.assertIn("NavigationLink(value: section)", settings)
        self.assertIn("navigationDestination(for: FindHausSettingsSection.self)", settings)
        self.assertIn("settings.sections", settings)
        self.assertIn('case .general: "الإعدادات العامة"', settings)
        self.assertNotIn('ScrollView(.horizontal', settings)
        self.assertNotIn('case .preferences: "التفضيلات"', settings)
        for page in [
            "SettingsPreferencesPage", "SettingsTravelTimePage",
            "SettingsListingDetailsPage", "SettingsApplicationPage",
            "SettingsNotificationsPage", "SettingsConnectionsPage",
            "SettingsMCPPage",
        ]:
            self.assertIn(page + "(", settings)
        self.assertIn("navigationPath.append(.connections)", settings)

    def test_native_login_is_a_complete_xcode_project(self):
        project = ROOT / "FredyTest.xcodeproj/project.pbxproj"
        self.assertTrue(project.is_file(), "Native Xcode project is not created yet")
        from openstep_parser import OpenStepDecoder
        from tree_sitter import Language, Parser
        import tree_sitter_swift

        with project.open() as stream:
            pbx = OpenStepDecoder.ParseFromFile(stream)
        objects = pbx["objects"]
        root = objects[pbx["rootObject"]]
        self.assertEqual(root["isa"], "PBXProject")
        targets = [objects[key] for key in root["targets"]]
        self.assertEqual(len(targets), 1)
        self.assertEqual(targets[0]["productType"], "com.apple.product-type.application")
        self.assertEqual(targets[0]["packageProductDependencies"], [])
        self.assertEqual(root["packageReferences"], [])

        files = list((ROOT / "Sources").rglob("*.swift"))
        self.assertEqual(len(files), 36)  # 32 existing + 4 Stage 2 source files
        parser = Parser(Language(tree_sitter_swift.language()))
        source = ""
        for path in files:
            raw = path.read_bytes()
            self.assertFalse(parser.parse(raw).root_node.has_error, f"Swift syntax: {path}")
            source += raw.decode("utf-8") + "\n"
        self.assertEqual(source.count("@main"), 1)
        self.assertIn("NavigationStack", source)
        self.assertIn("TabView", source)  # Native four-tab navigation, no forced About link
        for forbidden in ["AsyncImage", "WKWebView", "UserDefaults", "Keychain", "http://", "NSAllowsArbitraryLoads"]:
            self.assertNotIn(forbidden, source)
        self.assertFalse(list(ROOT.rglob("*.ipa")))
        self.assertFalse(list(ROOT.rglob("*.entitlements")))

        catalog = json.loads((ROOT / "Resources/Localizable.xcstrings").read_text())
        translation_source = re.sub(r'\.accessibilityIdentifier\("[^"]+"\)', "", source)
        keys = set(re.findall(r'"((?:home|about|login|listings|jobs|tabs)\.[a-z_]+)"', translation_source))
        self.assertTrue(keys)
        self.assertTrue(keys <= set(catalog["strings"]))
        # The user's selected FindHaus art is an actual Xcode app icon and image asset.
        assets = ROOT / "Resources/FindHausAssets.xcassets"
        app_icon = assets / "AppIcon.appiconset/FindHausIcon.png"
        login_logo = assets / "BrandLogo.imageset/FindHausIcon.png"
        for asset in [app_icon, login_logo]:
            raw = asset.read_bytes()
            self.assertEqual(raw[:8], b"\\x89PNG\\r\\n\\x1a\\n")
            self.assertEqual(struct.unpack(">II", raw[16:24]), (1024, 1024))
            self.assertEqual(hashlib.sha256(raw).hexdigest(),
                             "498f0da9ca74fa240e8dcb53f790e38adac0dcc53c4134a4020c05b32a66c6ce")
        icon_config = json.loads((assets / "AppIcon.appiconset/Contents.json").read_text())
        logo_config = json.loads((assets / "BrandLogo.imageset/Contents.json").read_text())
        self.assertEqual(icon_config["images"][0]["filename"], "FindHausIcon.png")
        self.assertEqual(logo_config["images"][0]["filename"], "FindHausIcon.png")
        self.assertIn("ASSETCATALOG_COMPILER_APPICON_NAME", project.read_text())
        self.assertIn("FindHaus", project.read_text())

        for key in keys:
            for locale in ["en", "ar"]:
                unit = catalog["strings"][key]["localizations"][locale]["stringUnit"]
                self.assertEqual(unit["state"], "translated")
                self.assertTrue(unit["value"])

        build_files = {item["fileRef"] for item in objects.values() if item["isa"] == "PBXBuildFile"}
        references = [objects[key] for key in build_files]
        compiled_sources = {item["path"] for item in references if item.get("lastKnownFileType") == "sourcecode.swift"}
        self.assertEqual(compiled_sources, {str(path.relative_to(ROOT)) for path in files})
        for item in references:
            self.assertTrue((ROOT / item["path"]).exists(), item["path"])
        for path in ROOT.rglob("*.xcscheme"):
            scheme = ET.parse(path)
            for reference in scheme.iter("BuildableReference"):
                self.assertIn(reference.attrib["BlueprintIdentifier"], root["targets"])
        ET.parse(ROOT / "FredyTest.xcodeproj/project.xcworkspace/contents.xcworkspacedata")
        configs = [item for item in objects.values() if item["isa"] == "XCBuildConfiguration"]
        for config in configs:
            settings = config["buildSettings"]
            self.assertNotIn("DEVELOPMENT_TEAM", settings)
            self.assertNotIn("NSAppTransportSecurity", str(settings))


if __name__ == "__main__":
    unittest.main(verbosity=2)
