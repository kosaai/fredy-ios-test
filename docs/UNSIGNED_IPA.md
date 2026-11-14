# First unsigned iPhone build

## Scope and workflow

The user authorized one real unsigned device-build attempt, not app changes or signing.
`.github/workflows/unsigned-ipa.yml` is a manual-only workflow whose JSON syntax is valid YAML 1.2. It has one job on **macos-26 only**, read-only contents permission, commit-pinned checkout/upload actions and no signing secrets. The project has no package dependencies to resolve/install. Existing app features and all 18 Swift sources are preserved unless a real compiler identifies a build blocker.

Preflight checks macOS major version 26 and prints the selected Xcode/device SDK. Release `xcodebuild` targets `-sdk iphoneos -destination generic/platform=iOS -arch arm64`, with signing allowed/required disabled, empty identity/team/profile, and no archive/export step. A separate 25-minute execution timeout is only a secondary bound; it does NOT enforce runner queue time.

After a successful compile, copy the complete Release-iphoneos `FredyTest.app` using ditto to `Payload/FredyTest.app`, ZIP Payload into `FredyTest-Unsigned.ipa`, and run `tools/verify_unsigned_ipa.py`. Check ZIP safety/integrity, device plist, arm64 Mach-O/iOS platform and absent signing material/code-signature command before upload. The IPA artifact is `FredyTest-Unsigned-<run-id>`, with a verification JSON, retained 14 days. Failure-only compiler logs are a different artifact and never evidence of an IPA.

Unsigned is **not directly installable** on a normal iPhone: external signing with compatible provisioning is a later, separately authorized step. Compilation/packaging is not proof that login, networking, tabs, RTL or VoiceOver work on a device.

## Reusable Oracle queue watchdog

Run from Oracle after committing/pushing and verifying main:

```sh
python3 tools/actions_queue.py --repo kosaai/fredy-ios-test \
  --workflow unsigned-ipa.yml --ref main --sha <exact-40-character-head-sha> \
  --queue-timeout 300 --output <new-absolute-path-outside-repository.json>
```

The helper verifies the ref, dispatches exactly once with a unique run-name tag, resolves that exact SHA/tag/run, and starts the absolute monotonic 300-second deadline immediately before dispatch. Discovery time counts toward the window. Poll requests have bounded timeouts and short waits clamped to the remaining window. A queued `started_at` timestamp or runner assignment alone is NOT execution: require the expected macos-26 job, nonzero runner ID and a genuinely started in-progress/completed step.

If no execution is observed before the deadline, initiate cancellation immediately and report **macOS runner unavailable**; read back that exact run to verify terminal status. Never switch runner labels, dispatch/re-run automatically or rely on workflow timeout-minutes. A terminal job without execution is also unavailable, not a compiler failure. A mismatched runner label is cancelled as a policy error. No automatic dispatch retry occurs even when the first response is uncertain; the unique tag is resolved instead.

Once execution is observed, monitor the build to completion (bounded separately), record exact conclusion/artifact metadata and return it. A successful run alone is not an artifact verification: download the exact unsigned-IPA artifact from GitHub, rerun the verifier on Oracle and compare its SHA-256 with the uploaded verification JSON before offering a download.

API/service outages cannot guarantee remote cancellation. The helper records uncertain dispatch/cancel state rather than claiming cancellation; manually inspect the exact run before closing. If dispatch identity is unresolved, never guess or cancel unrelated runs. Keep the external watchdog alive until a verified result; it is not an in-workflow timer. Interrupting a known run requests cancellation. Reports/IPA/logs stay outside Git and Graphify. These contain run metadata, not credentials.

## Evidence status

The first live attempt was interrupted in the Oracle agent session; its background queue monitor exited with code 1. That exit code alone is not a compiler log, and no IPA artifact has been independently verified. The original run ID, exact failing step and runner start time remain unverified.

Workflow maintenance on 2026-11-14: converted the workflow to readable YAML, used the explicit Xcode PBX target rather than requiring a generated/shared scheme, and replaced the scheme-specific `-derivedDataPath` option with target-compatible `SYMROOT`, `OBJROOT` and `CONFIGURATION_BUILD_DIR` paths. Packaging now reads `build/Products/Release-iphoneos/FredyTest.app`. The external Oracle monitor now prints failed Actions step names on a failed run. These are reviewed configuration changes, not proof of a successful macOS build.

Do not rerun automatically. On the next *explicitly authorized* attempt use the existing 300-second Oracle queue watchdog and check the exact GitHub Actions failed step or successful artifact before reporting the outcome.

Local tests use explicit synthetic job metadata, fake clocks and minimal structural ZIP/Mach-O fixtures only to test watchdog/verifier branches; none are app mock data or a deliverable IPA. App source tests and tool unit tests are not an Xcode compile. No Apple signing data, Fredy or Cloudflare changes are included.
