// Zsignwrapper.hpp
// C++ bridge between the Objective-C ZSignWrapper (ZSignwrapper.mm) and the
// zsign signing engine (ZSignAsset / ZBundle / Zip).
// Copyright (c) 2026 FreeSign

#ifndef ZSIGNWRAPPER_HPP
#define ZSIGNWRAPPER_HPP

#include <string>
#include <vector>

#include "common.h"
#include "openssl.h"
#include "bundle.h"
#include "archive.h"

class ZSignWrapperCPP
{
public:
	ZSignWrapperCPP()
		: m_bInit(false)
	{
	}

	// Initializes the signing asset (certificate, private key, provisioning profile).
	bool InitWithCert(const std::string& strCertFile,
					  const std::string& strPKeyFile,
					  const std::string& strProvFile,
					  const std::string& strPassword,
					  const std::string& strEntitleFile,
					  bool bAdhoc,
					  bool bSHA256Only)
	{
		m_bInit = m_zsa.Init(strCertFile, strPKeyFile, strProvFile, strEntitleFile,
							 strPassword, bAdhoc, bSHA256Only, false);
		if (!m_bInit) {
			m_strError = "Failed to load signing certificate. Check that the p12/pem, "
						 "password and provisioning profile are valid.";
		}
		return m_bInit;
	}

	std::string GetLastError() const
	{
		return m_strError;
	}

	// Signs an IPA file: extract -> sign bundle -> re-archive as Payload/.
	bool SignIPA(const std::string& strIPA,
				 const std::string& strOutput,
				 const std::string& strBundleId,
				 const std::string& strBundleVersion,
				 const std::string& strBundleName)
	{
		if (!m_bInit) {
			m_strError = "Signing engine is not initialized.";
			return false;
		}
		if (strIPA.empty() || strOutput.empty()) {
			m_strError = "Invalid input or output path.";
			return false;
		}
		if (!ZFile::IsFileExists(strIPA.c_str())) {
			m_strError = "Input IPA not found: " + strIPA;
			return false;
		}

		std::string strTempFolder = ZFile::GetTempFolder();
		std::string strFolder = ZFile::GetRealPathV("%s/zsign_folder_%llu",
													 strTempFolder.c_str(),
													 ZUtil::GetMicroSecond());

		if (!Zip::Extract(strIPA.c_str(), strFolder.c_str())) {
			m_strError = "Failed to extract IPA archive.";
			return false;
		}

		ZBundle bundle;
		if (!bundle.SignFolder(&m_zsa, strFolder, strBundleId, strBundleVersion, strBundleName,
							   std::vector<std::string>(), std::vector<std::string>(),
							   true, false, false)) {
			m_strError = "Failed to sign the app bundle.";
			ZFile::RemoveFolder(strFolder.c_str());
			return false;
		}

		size_t pos = bundle.m_strAppFolder.rfind("Payload");
		if (std::string::npos == pos || pos == 0) {
			m_strError = "Can't find Payload directory in signed bundle.";
			ZFile::RemoveFolder(strFolder.c_str());
			return false;
		}

		std::string strBaseFolder = bundle.m_strAppFolder.substr(0, pos - 1);
		bool bArchived = Zip::Archive(strBaseFolder.c_str(), strOutput.c_str(), 0);
		ZFile::RemoveFolder(strFolder.c_str());

		if (!bArchived) {
			m_strError = "Failed to archive signed IPA.";
		}
		return bArchived;
	}

	// Signs an already-extracted .app folder in place.
	bool SignAppFolder(const std::string& strAppFolder,
					   const std::string& strBundleId,
					   const std::string& strBundleVersion,
					   const std::string& strBundleName)
	{
		if (!m_bInit) {
			m_strError = "Signing engine is not initialized.";
			return false;
		}
		if (!ZFile::IsFolder(strAppFolder.c_str())) {
			m_strError = "App folder not found: " + strAppFolder;
			return false;
		}

		ZBundle bundle;
		if (!bundle.SignFolder(&m_zsa, strAppFolder, strBundleId, strBundleVersion, strBundleName,
							   std::vector<std::string>(), std::vector<std::string>(),
							   true, false, false)) {
			m_strError = "Failed to sign the app bundle.";
			return false;
		}
		return true;
	}

	// Extracts an IPA into the given output folder (produces Payload/ inside it).
	static bool ExtractIPA(const std::string& strIPA, const std::string& strOutputFolder)
	{
		return Zip::Extract(strIPA.c_str(), strOutputFolder.c_str());
	}

	// Archives a folder (the one containing Payload/) into an IPA file.
	static bool ArchiveIPA(const std::string& strBaseFolder, const std::string& strIPA)
	{
		return Zip::Archive(strBaseFolder.c_str(), strIPA.c_str(), 0);
	}

private:
	ZSignAsset	m_zsa;
	bool		m_bInit;
	std::string	m_strError;
};

#endif // ZSIGNWRAPPER_HPP
