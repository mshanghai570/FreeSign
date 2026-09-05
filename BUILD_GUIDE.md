# FreeSign iOS Build and Readiness Guide

FreeSign is an iOS IPA management and signing app. It imports IPA archives, manages PKCS#12 identities and provisioning profiles, signs IPAs locally with the bundled signing engine, and can export the signed archive to a receiving sideloading tool. The Lab Assistant supports user-configured OpenAI-compatible, Gemini, Anthropic, and HTTPS local-model endpoints.

## Prerequisites

A development Mac must have **Xcode 16.2 or later**, an iOS 18.2 simulator runtime for tests, and an Apple ID signed in to Xcode. To install a development build directly from Xcode, select an Apple Development team for the **FreeSign** target under **Signing & Capabilities**. The project is configured for automatic signing; the repository deliberately does not contain a personal development-team identifier, certificate, or provisioning profile.

The project resolves [OpenSSL-Package](https://github.com/krzyzanowskim/OpenSSL-Package) through Swift Package Manager. Xcode must have Internet access the first time dependencies are resolved.

## First-Time Xcode Setup

1. Open `FreeSign.xcodeproj` in Xcode.
2. Allow Xcode to resolve package dependencies.
3. Select the **FreeSign** application target, open **Signing & Capabilities**, and select the intended Apple Development team.
4. Confirm that the bundle identifier `com.freesign.app` is available to that team, or change it to an identifier you control.
5. Choose an iOS 18.2-or-later simulator and run the unit tests before using a device.

The separate unit-test command below disables code signing only for simulator CI. Do not disable signing in the application target when testing on a physical device.

## Build and Test

### Run tests in Xcode

Use **Product → Test** after choosing an available iPhone simulator. The project includes a GitHub Actions workflow at `.github/workflows/ios-ci.yml` that resolves dependencies and runs the same test scheme on macOS for pushes and pull requests to `master`.

### Run tests from Terminal

```bash
xcodebuild test \
  -project FreeSign.xcodeproj \
  -scheme FreeSign \
  -destination 'platform=iOS Simulator,name=iPhone 16' \
  CODE_SIGNING_ALLOWED=NO
```

If the named simulator is unavailable, open Xcode’s **Window → Devices and Simulators** and substitute an installed device name or identifier.

### Build an unsigned IPA for a sideloading tool

The project-root script builds a device archive without applying the developer-machine signature and packages it as an IPA. This is useful when a separate sideloading tool will sign the application.

```bash
chmod +x build_unsigned_ipa.sh build_simple.sh
./build_unsigned_ipa.sh Release
```

The finished IPA and build log are written under `build/`. `build_simple.sh` remains as a backward-compatible wrapper around this maintained command.

### Build a device development build in Xcode

After selecting a team, choose a connected device and use **Product → Run**. Xcode will sign the app with your development identity. This is the appropriate route for direct device debugging.

## In-App Signing Workflow

1. Import an IPA in the Library tab.
2. Import a `.p12`/`.pfx` certificate and attach a compatible, unexpired `.mobileprovision` profile in Certificates.
3. Open **Sign & Export** from an imported IPA.
4. Optionally change the display name, bundle ID, version, minimum iOS version, custom entitlements, icon, dylib injection list, or supported native options.
5. Sign the IPA. The output is retained in the app container at `Documents/Signed` and appears in FreeSign’s signed-app history.
6. Choose **Export IPA** and send the archive to AltStore, SideStore, Files, or another receiving sideloading tool. iOS does not permit an ordinary app to install a local IPA directly; the receiving tool performs installation.

FreeSign preflights the source IPA, certificate file, certificate/profile expiry, entitlement file, and bundle-ID coverage before it starts the native signing operation. In ad-hoc mode, it does not require a certificate/profile, but the resulting archive is appropriate only for workflows that accept ad-hoc signatures.

## Lab Assistant Setup and Privacy

Add an AI provider in **Settings → Lab Assistant**. Provider keys are held in the iOS Keychain and are not stored in FreeSign’s preferences. The assistant defaults are:

| Provider | Default model |
| --- | --- |
| OpenAI-compatible | `gpt-5.6-luna` |
| Gemini | `gemini-3.8-flash` |
| Anthropic | `claude-sonnet-5` |

Use **Test Connection** to issue a small, explicit request against the selected endpoint, key, and model. The test consumes a provider request and requires a nonempty reply.

**Current-screen context sharing is disabled by default.** When disabled, FreeSign sends the user’s question and a generic task instruction but does not include app, source, file, certificate, or visible-tab summary metadata. Enable **Share Current-Screen Context** only when that information is appropriate to send to the selected provider.

All AI endpoints must use **HTTPS**, including local inference servers. The Local Model provider speaks the OpenAI-compatible Chat Completions protocol and uses an imported model file name only as the `model` identifier sent to that server; it does not run GGUF or MLX inference on-device.

Use **Erase AI Data** in Lab Assistant settings to permanently remove all configured AI providers, every FreeSign AI API key stored in Keychain, and saved assistant conversations. The general **Reset All Settings** action presents the same data-erasure disclosure before proceeding. See [provider model verification](docs/provider-model-verification.md) for the current default-model sources.

## Troubleshooting

| Symptom | Resolution |
| --- | --- |
| Xcode says a development team is required | Select your team under **FreeSign → Signing & Capabilities** and use an identifier owned by that team. |
| Swift package dependency fails to resolve | Check the network connection, then use **File → Packages → Reset Package Caches** and resolve again. |
| The assistant reports an insecure endpoint | Configure HTTPS/TLS on the provider or local inference server; FreeSign deliberately blocks cleartext HTTP requests. |
| Signing says the profile does not cover the bundle ID | Select a profile whose exact or wildcard application identifier covers the effective bundle identifier, or change the requested identifier. |
| A signed IPA is ready but is not installed | Use **Export IPA** and select a sideloading tool. Installation is intentionally delegated to that receiving tool. |

## Clean Build

```bash
rm -rf ~/Library/Developer/Xcode/DerivedData/FreeSign*
xcodebuild -resolvePackageDependencies -project FreeSign.xcodeproj -scheme FreeSign
xcodebuild test -project FreeSign.xcodeproj -scheme FreeSign \
  -destination 'platform=iOS Simulator,name=iPhone 16' CODE_SIGNING_ALLOWED=NO
```

Do not commit personal certificates, provisioning profiles, API keys, or a personal `DEVELOPMENT_TEAM` setting to the repository.
