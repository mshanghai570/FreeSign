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

bridge = read("ZSignWrapper+Swift.swift")
if "throws -> [AnyHashable: Any]" not in bridge or "guard let dictionary" not in bridge:
    errors.append("Certificate bridge still permits a silent nil dictionary result")

certificate_bridge = read("ZSignwrapper.mm")
for fragment, label in {
    "kSecOIDX509V1ValidityNotAfter": "Certificate expiration extraction",
    "kSecOIDX509V1SerialNumber": "Certificate serial-number extraction",
    'result[@"expirationDate"]': "Certificate expiration metadata result",
}.items():
    if fragment not in certificate_bridge:
        errors.append(f"{label} is missing")

keychain = read("FreeSign/Utilities/KeychainHelper.swift")
if "saveCertificatePassword" not in keychain or "loadCertificatePasswordSync" not in keychain:
    errors.append("Certificate password Keychain helpers are missing")
if 'password: ""' not in importer or "saveCertificatePassword" not in importer:
    errors.append("New certificate imports do not keep passwords out of persisted metadata")
signing_manager = read("FreeSign/Utilities/SigningManager.swift")
if "loadCertificatePasswordSync" not in signing_manager:
    errors.append("Signing does not read protected certificate passwords")

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
