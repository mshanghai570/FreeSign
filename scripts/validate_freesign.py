#!/usr/bin/env python3
"""Static integration checks for FreeSign when Xcode is unavailable."""
from __future__ import annotations

import plistlib
import re
import sys
from pathlib import Path

ROOT = Path(__file__).resolve().parents[1]
errors: list[str] = []


def read(relative_path: str) -> str:
    path = ROOT / relative_path
    if not path.is_file():
        errors.append(f"Missing required file: {relative_path}")
        return ""
    return path.read_text(encoding="utf-8")


def require(relative_path: str, pattern: str, label: str) -> None:
    text = read(relative_path)
    if not re.search(pattern, text, flags=re.DOTALL):
        errors.append(f"{label}: expected pattern not found in {relative_path}")


# Primary tab assistant coverage and assistant identifiers.
main_tab = read("FreeSign/Views/TabBar/MainTabView.swift")
for tab in ("LibraryView", "SourcesView", "AppsView", "FilesView", "SettingsView"):
    if tab not in main_tab:
        errors.append(f"Primary tab wiring is missing {tab}")

for tab, path in {
    "Library": "FreeSign/Views/Library/LibraryView.swift",
    "Sources": "FreeSign/Views/Sources/SourcesView.swift",
    "Apps": "FreeSign/Views/Sources/AppsView.swift",
    "Files": "FreeSign/Views/Files/FilesView.swift",
    "Settings": "FreeSign/Views/Settings/SettingsView.swift",
}.items():
    require(path, rf'TabAssistantButton\(\s*sourceView: "{tab}"', f"{tab} assistant coverage")
    require(path, r"details:", f"{tab} detailed context")

assistant = read("FreeSign/Views/Lab/TabAssistantView.swift")
for fragment, label in {
    "AIService.shared.messages(for: sourceView)": "Per-tab conversation restore",
    "AIService.shared.saveConversation": "Per-tab conversation persistence",
    "details: details": "Fresh tab snapshot passed to AI service",
    'accessibilityIdentifier("tabAssistant.': "Assistant accessibility identifier",
}.items():
    if fragment not in assistant:
        errors.append(f"{label} is missing")

# Certificate entry points must queue a password-first flow.
importer = read("FreeSign/Utilities/FileImporter.swift")
for fragment, label in {
    "@Published var pendingCertificateURL": "Pending certificate state",
    "func prepareCertificateImport": "Certificate import queue",
    "func importCertificate(fromLocalURL": "Password-backed certificate import",
    "password.isEmpty ? nil : password": "Optional P12 password support",
}.items():
    if fragment not in importer:
        errors.append(f"{label} is missing")

files_view = read("FreeSign/Views/Files/FilesView.swift")
if "onImportCertificate:" not in files_view or "prepareCertificateImport(from: file.url)" not in files_view:
    errors.append("Files tab does not route P12/PFX files to the certificate import flow")

file_row = read("FreeSign/Views/Files/Components/FileRow.swift")
if "if file.isP12Certificate" not in file_row or "onImportCertificate(file)" not in file_row:
    errors.append("Certificate file row does not open the certificate import route")

certificate_view = read("FreeSign/Views/Certificates/CertificatesView.swift")
if ".toolbar { toolbarContent }" not in certificate_view:
    errors.append("Certificate management toolbar is missing")
if 'accessibilityIdentifier("certificates.importP12")' not in certificate_view:
    errors.append("Certificate import accessibility identifier is missing")

bridge = read("FreeSign/Utilities/ZSignWrapper+Swift.swift")
if "throws -> [AnyHashable: Any]" not in bridge or "guard let dictionary" not in bridge:
    errors.append("Certificate bridge still permits a silent nil dictionary result")
if (ROOT / "ZSignWrapper+Swift.swift").exists():
    errors.append("Swift signing bridge must live under the filesystem-synchronized FreeSign source group")

certificate_bridge = read("ZSignwrapper.mm")
for fragment, label in {
    "SecCertificateCopySubjectSummary": "Certificate subject extraction",
    "SecCertificateCopyCommonName": "Certificate common-name extraction",
}.items():
    if fragment not in certificate_bridge:
        errors.append(f"{label} is missing")
for fragment in ("SecCertificateCopyValues", "kSecOIDX509V1ValidityNotAfter", "kSecOIDX509V1SerialNumber"):
    if fragment in certificate_bridge:
        errors.append(f"iOS-incompatible Security certificate value API remains: {fragment}")

keychain = read("FreeSign/Utilities/KeychainHelper.swift")
if "saveCertificatePassword" not in keychain or "loadCertificatePasswordSync" not in keychain:
    errors.append("Certificate password Keychain helpers are missing")
if 'password: ""' not in importer or "saveCertificatePassword" not in importer:
    errors.append("New certificate imports do not keep passwords out of persisted metadata")
signing_manager = read("FreeSign/Utilities/SigningManager.swift")
if "loadCertificatePasswordSync" not in signing_manager:
    errors.append("Signing does not read protected certificate passwords")

# A completed signing flow must use the option-aware native bridge, retain the
# output in Documents/Signed, and offer a real user-mediated IPA export action.
for fragment, label in {
    "ZSignWrapper.signIPAWithOptions": "Option-aware native signing call",
    "StorageManager.shared.signedURL": "Persistent signed IPA storage",
    "certificate: Certificate?": "Ad-hoc signing support",
    "writeTemporaryIcon": "Icon override staging",
}.items():
    if fragment not in signing_manager:
        errors.append(f"{label} is missing from SigningManager")

signing_bridge = read("ZSignwrapper.mm")
for fragment, label in {
    "signIPAWithOptionsAtPath": "Option-aware Objective-C signing bridge",
    "entitlementsPath": "Custom entitlements bridge parameter",
    "injectDylibs": "Dylib injection bridge parameter",
    "removeUISupportedDevices": "Bundle modification bridge parameter",
}.items():
    if fragment not in signing_bridge:
        errors.append(f"{label} is missing from the native signing bridge")

native_wrapper = read("Zsignwrapper.hpp")
for fragment, label in {
    "const std::vector<std::string>& arrInjectDylibs": "Native injection option",
    "bundle.m_bEnableDocuments": "Native documents option",
    "bundle.m_bRemoveExtensions": "Native extension-removal option",
    "bundle.m_strIconFile": "Native icon option",
}.items():
    if fragment not in native_wrapper:
        errors.append(f"{label} is missing from the native signing wrapper")

signing_view = read("FreeSign/Views/Signing/SigningView.swift")
for fragment, label in {
    "ActivityShareSheet(items: [signedIPAURL])": "Signed IPA export sheet",
    "isShowingSigningCompletion": "Signing completion feedback",
    "isShowingSigningError": "Signing failure feedback",
    "minOSVersion: temporaryOptions.minimumAppRequirement": "Minimum iOS version forwarding",
}.items():
    if fragment not in signing_view:
        errors.append(f"{label} is missing from the signing view")

if "ActivityShareSheet" not in read("FreeSign/Utilities/ActivityShareSheet.swift"):
    errors.append("Signed IPA export sheet implementation is missing")

analyzer = read("FreeSign/Utilities/IPAAnalyzer.swift")
if "removeItem(atPath: extractedPath)" not in analyzer:
    errors.append("IPA analyzer does not clean up its actual temporary extraction")
for fragment, label in {
    "loadUnaligned": "Unaligned Mach-O reads",
    "commandSize <= data.count - offset": "Mach-O command bounds validation",
    "offset + 20 <= data.count": "Fat Mach-O bounds validation",
}.items():
    if fragment not in analyzer:
        errors.append(f"IPA analyzer is missing {label}")

project = read("FreeSign.xcodeproj/project.pbxproj")
for forbidden, label in {
    "/usr/local/Cellar/openssl": "machine-specific OpenSSL include path",
    "CODE_SIGNING_ALLOWED = NO;": "disabled app signing",
    "CODE_SIGN_STYLE = Manual;": "manual app signing override",
}.items():
    if forbidden in project:
        errors.append(f"Project retains {label}")
if project.count("CODE_SIGN_STYLE = Automatic;") < 2:
    errors.append("App target does not use automatic signing for Debug and Release")

for native_path in ("openssl.cpp", "signing.cpp", "common/sha.cpp", "certcheck.cpp"):
    native_source = read(native_path)
    if "<OpenSSL/OpenSSL.h>" not in native_source or "<openssl/" in native_source:
        errors.append(f"{native_path} does not use the portable OpenSSL framework umbrella header")

ai_settings = read("FreeSign/Models/AI/AISettings.swift")
for fragment, label in {
    "var sendContextByDefault: Bool = false": "private-by-default context sharing",
    "func eraseAllData() async": "AI data-erasure lifecycle",
    "func deactivateProvider()": "provider deactivation lifecycle",
}.items():
    if fragment not in ai_settings:
        errors.append(f"AI settings lacks {label}")

assistant_settings = read("FreeSign/Views/Settings/AssistantSettingsView.swift")
for fragment, label in {
    "Share Current-Screen Context": "context-sharing control",
    "Erase API Keys, Providers, and Conversations": "confirmed AI-data erasure control",
    "AISettings.shared.deactivateProvider()": "working provider deactivation",
}.items():
    if fragment not in assistant_settings:
        errors.append(f"Assistant settings lacks {label}")

if "var aiApiKey" in read("FreeSign/Models/Settings.swift"):
    errors.append("Legacy plaintext AI API key field remains in app settings")

transport = read("FreeSign/Services/AI/AIProviderProtocol.swift")
if "case insecureEndpoint" not in transport or 'guard scheme == "https"' not in transport:
    errors.append("AI provider transport does not require HTTPS")
if "throw CancellationError()" not in transport:
    errors.append("AI provider transport does not propagate cancellation")

for provider_path in (
    "FreeSign/Services/AI/Providers/OpenAICompatibleProvider.swift",
    "FreeSign/Services/AI/Providers/AnthropicProvider.swift",
    "FreeSign/Services/AI/Providers/GeminiProvider.swift",
    "FreeSign/Services/AI/Providers/LocalModelProvider.swift",
):
    if "continuation.onTermination" not in read(provider_path):
        errors.append(f"{provider_path} does not cancel a request when its stream terminates")

notebook = read("FreeSign/Views/Lab/LabNotebookView.swift")
for fragment, label in {
    "AIService.shared.notebookConversations()": "Lab Notebook persistence load",
    "saveNotebookConversation": "Lab Notebook persistence save",
    "history: Array(conversation.messages.dropLast())": "Lab Notebook multi-turn history",
    "requestTask?.cancel()": "Lab Notebook request cancellation",
}.items():
    if fragment not in notebook:
        errors.append(f"Notebook lacks {label}")

# Provider format contracts.
provider_protocol = read("FreeSign/Services/AI/AIProviderProtocol.swift")
for fragment, label in {
    "AIProviderMessageFormatter": "Provider-specific message formatter",
    "anthropicMessages": "Anthropic role conversion",
    "geminiContents": "Gemini role conversion",
    "systemPrompt(from": "System prompt separation",
    "case emptyResponse": "Empty provider response handling",
}.items():
    if fragment not in provider_protocol:
        errors.append(f"{label} is missing")

anthropic = read("FreeSign/Services/AI/Providers/AnthropicProvider.swift")
gemini = read("FreeSign/Services/AI/Providers/GeminiProvider.swift")
openai = read("FreeSign/Services/AI/Providers/OpenAICompatibleProvider.swift")
if 'body["system"] = systemPrompt' not in anthropic:
    errors.append("Anthropic system prompt is not sent through the supported system field")
if '"x-goog-api-key"' not in gemini or '"systemInstruction"' not in gemini:
    errors.append("Gemini request does not use API-key header and systemInstruction")
if "AIProviderMessageFormatter.openAIChatMessages" not in openai:
    errors.append("OpenAI-compatible request does not use normalized chat messages")

# Document declarations and plist health.
plist_path = ROOT / "FreeSignTarget-Info.plist"
try:
    with plist_path.open("rb") as handle:
        plist = plistlib.load(handle)
    imported = plist.get("UTImportedTypeDeclarations", [])
    certificate_types = [item for item in imported if item.get("UTTypeIdentifier") == "com.rsa.pkcs-12"]
    extensions = certificate_types[0]["UTTypeTagSpecification"]["public.filename-extension"] if certificate_types else []
    if not {"p12", "pfx"}.issubset(set(extensions)):
        errors.append("Info.plist does not declare both P12 and PFX certificate extensions")
except Exception as exc:  # noqa: BLE001
    errors.append(f"Info.plist could not be parsed: {exc}")

if errors:
    print("FreeSign source validation failed:")
    for error in errors:
        print(f"- {error}")
    sys.exit(1)

print("FreeSign source validation passed.")
