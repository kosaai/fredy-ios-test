# Fredy Test

A minimal, independently authored native SwiftUI iPhone test shell. This is a local UI scaffold, not a functional Fredy client. No Fredy source, logo, account data, server URL or credentials are included.

## Open the project

Requirements: Xcode 15 or later; iOS 17 or later. Open `FredyTest.xcodeproj` and select the shared `FredyTest` scheme. No third-party app dependencies or project generator are required. Device signing needs your own development team; none is embedded.

## Structure

```text
Sources/
  App/                    # App entry point and root NavigationStack
  Features/Home/          # Local welcome screen
  Features/About/         # Scope and interface information
  Shared/Components/      # Reusable InfoBlock view
Resources/
  Localizable.xcstrings   # English and Arabic
FredyTest.xcodeproj/      # Native Xcode project and shared scheme
Tests/
  validate_project.py     # Offline structural/syntax checks
  requirements.txt        # Development-only validation tools
```

One application target, five small Swift files. No unnecessary view models, service layer, global state or routing framework.

## Interface

- Two local screens with standard NavigationStack, List, Sections, NavigationLink and system back navigation.
- System text styles and semantic colors; follows system appearance and text sizing.
- English and Arabic translations, native leading alignment and automatic RTL. No forced production language or layout direction.
- Text-labelled navigation, a 44 pt minimum navigation label height, accessibility identifiers and a decorative symbol hidden from VoiceOver.
- Previews for English and for Arabic/RTL with dark appearance and large accessibility text. Previews have not been rendered on this host.
- No custom animation, permission prompts, custom Liquid Glass, third-party SDKs or copied assets. SF Symbols are used only in the interface, not as app branding.

## Guidance used

Installed skills: `swiftui-ui-patterns`, `swiftui-expert-skill`, and `apple-hig`.

Apple HIG operative guidance: “Be clear and direct.” (Design principles); “Adapt to orientation, Dark Mode, and Dynamic Type.” (Designing for iOS). Native components, system typography and unclipped multiline content apply those principles. This is not a certification of HIG or accessibility compliance.

- https://developer.apple.com/design/human-interface-guidelines/design-principles
- https://developer.apple.com/design/human-interface-guidelines/designing-for-ios
- https://developer.apple.com/design/human-interface-guidelines/accessibility

## Scope deliberately excluded

No login, networking, server configuration, listing/job models or screens, persistence, push notifications, analytics, live fixtures, CI/release automation, archive or IPA. No existing repository, Fredy container or Cloudflare configuration was changed.

## Project memory and public safety

- `PROJECT_HISTORY.md`: sanitized completed stages, API findings, decisions and evidence limits.
- `HANDOFF.md`: current status, verified gaps and explicitly deferred next steps.
- `AGENTS.md`: future Codex completion rules, including history/handoff, safe incremental Graphify refresh, then commit/push to main.
- `docs/GRAPHIFY.md`: external offline index and maintenance commands.
- `tools/public-scope.json`: exact public-file and graph-input allowlists. Original reports, raw responses and deployment material are not included.

## Verification

Run the development-only checks with a Python environment that has `Tests/requirements.txt` installed:

```sh
python3 Tests/validate_project.py
```

Checks parse the OpenStep Xcode project and all five Swift source files; verify source/resource membership, scheme identifiers, complete English/Arabic translations, and absence of network APIs, server URLs, signing secrets and IPA artifacts.

**Result on Oracle Linux: PASS.** These are structural and syntax checks, not Swift type-checking. Xcode and SwiftUI SDKs are unavailable on this host, so compilation, simulator launch, preview rendering, VoiceOver and visual verification remain untested. No IPA or archive was produced.
