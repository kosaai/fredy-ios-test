"""Offline scaffold checks, not a substitute for an Xcode build/UI run.

Optional parsers (installed outside this project):
  python -m pip install tree-sitter tree-sitter-swift openstep-parser
Run: python Tests/validate_project.py
"""
import json
from pathlib import Path
import re
import unittest
import xml.etree.ElementTree as ET

ROOT = Path(__file__).resolve().parents[1]


class NativeProjectChecks(unittest.TestCase):
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
        self.assertEqual(len(files), 22)
        parser = Parser(Language(tree_sitter_swift.language()))
        source = ""
        for path in files:
            raw = path.read_bytes()
            self.assertFalse(parser.parse(raw).root_node.has_error, f"Swift syntax: {path}")
            source += raw.decode("utf-8") + "\n"
        self.assertEqual(source.count("@main"), 1)
        self.assertIn("NavigationStack", source)
        self.assertIn("NavigationLink", source)
        for forbidden in ["AsyncImage", "WKWebView", "UserDefaults", "Keychain", "http://", "NSAllowsArbitraryLoads"]:
            self.assertNotIn(forbidden, source)
        self.assertFalse(list(ROOT.rglob("*.ipa")))
        self.assertFalse(list(ROOT.rglob("*.entitlements")))

        catalog = json.loads((ROOT / "Resources/Localizable.xcstrings").read_text())
        translation_source = re.sub(r'\.accessibilityIdentifier\("[^"]+"\)', "", source)
        keys = set(re.findall(r'"((?:home|about|login|listings|jobs|tabs)\.[a-z_]+)"', translation_source))
        self.assertTrue(keys)
        self.assertTrue(keys <= set(catalog["strings"]))
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
