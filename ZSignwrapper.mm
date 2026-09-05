// ZSignwrapper.mm
// Objective-C++ bridge between Swift and the Zsign C++ engine
// Copyright (c) 2026 FreeSign

#import "ZSignwrapper.h"
#import <Foundation/Foundation.h>
#import <Security/Security.h>
#import <Security/SecCertificateOIDs.h>

#include <string>
#include <vector>

#include "Zsignwrapper.hpp"

// -----------------------------------------------------------
// ZSignResult implementation
// -----------------------------------------------------------
@implementation ZSignResult

+ (instancetype)resultWithSuccess:(BOOL)success
                     errorMessage:(nullable NSString *)errorMessage
                       outputPath:(nullable NSString *)outputPath
{
    ZSignResult *result = [[ZSignResult alloc] init];
    result.success = success;
    result.errorMessage = errorMessage;
    result.outputPath = outputPath;
    return result;
}

@end

// -----------------------------------------------------------
// Helper: Convert NSError domain/message from C++ string
// -----------------------------------------------------------
static NSString *const kZSignErrorDomain = @"com.freesign.zsign";

static NSError *makeError(NSString *message)
{
    if (!message) {
        message = @"Unknown signing error";
    }
    return [NSError errorWithDomain:kZSignErrorDomain
                               code:-1
                           userInfo:@{NSLocalizedDescriptionKey: message}];
}

static NSError *makeErrorFromCPP(const std::string &msg)
{
    return makeError([NSString stringWithUTF8String:msg.c_str()]);
}

// -----------------------------------------------------------
// Helper: Get a temporary output path if none provided
// -----------------------------------------------------------
static NSString *outputPathForIPA(NSString *ipaPath, NSString *outputPath)
{
    if (outputPath) {
        return outputPath;
    }
    // Generate a temp path in the app's temporary directory
    NSString *tempDir = NSTemporaryDirectory();
    NSString *inputName = [ipaPath lastPathComponent];
    NSString *baseName = [inputName stringByDeletingPathExtension];
    NSString *signedName = [NSString stringWithFormat:@"%@_signed.ipa", baseName];
    return [tempDir stringByAppendingPathComponent:signedName];
}

// -----------------------------------------------------------
// Helper: Get a temp folder for extraction
// -----------------------------------------------------------
static NSString *tempExtractFolder()
{
    NSString *tempDir = NSTemporaryDirectory();
    NSString *folderName = [NSString stringWithFormat:@"freesign_extract_%llu",
                             (unsigned long long)[[NSDate date] timeIntervalSince1970] * 1000000];
    return [tempDir stringByAppendingPathComponent:folderName];
}

// -----------------------------------------------------------
// ZSignWrapper implementation
// -----------------------------------------------------------
@implementation ZSignWrapper

+ (ZSignResult *)signIPAAtPath:(NSString *)ipaPath
                    certPath:(nullable NSString *)certPath
                    pkeyPath:(nullable NSString *)pkeyPath
                    provPath:(nullable NSString *)provPath
                    password:(nullable NSString *)password
                    bundleId:(nullable NSString *)bundleId
                  bundleName:(nullable NSString *)bundleName
               bundleVersion:(nullable NSString *)bundleVersion
                  outputPath:(nullable NSString *)outputPath
{
    NSString *resolvedOutput = outputPathForIPA(ipaPath, outputPath);

    ZSignWrapperCPP wrapper;
    
    BOOL isAdhoc = (certPath == nil && pkeyPath == nil);
    
    if (!wrapper.InitWithCert(
            certPath ? std::string([certPath UTF8String]) : "",
            pkeyPath ? std::string([pkeyPath UTF8String]) : "",
            provPath ? std::string([provPath UTF8String]) : "",
            password ? std::string([password UTF8String]) : "",
            "",
            isAdhoc,
            true
        ))
    {
        return [ZSignResult resultWithSuccess:NO
                                errorMessage:[NSString stringWithUTF8String:wrapper.GetLastError().c_str()]
                                  outputPath:nil];
    }

    bool success = wrapper.SignIPA(
        std::string([ipaPath UTF8String]),
        std::string([resolvedOutput UTF8String]),
        bundleId ? std::string([bundleId UTF8String]) : "",
        bundleVersion ? std::string([bundleVersion UTF8String]) : "",
        bundleName ? std::string([bundleName UTF8String]) : ""
    );

    return [ZSignResult resultWithSuccess:success ? YES : NO
                             errorMessage:success ? nil : [NSString stringWithUTF8String:wrapper.GetLastError().c_str()]
	                               outputPath:success ? resolvedOutput : nil];
}

+ (ZSignResult *)signIPAWithOptionsAtPath:(NSString *)ipaPath
                                 certPath:(nullable NSString *)certPath
                                 pkeyPath:(nullable NSString *)pkeyPath
                                 provPath:(nullable NSString *)provPath
                           entitlementsPath:(nullable NSString *)entitlementsPath
                                 password:(nullable NSString *)password
                                 bundleId:(nullable NSString *)bundleId
                               bundleName:(nullable NSString *)bundleName
                            bundleVersion:(nullable NSString *)bundleVersion
                               outputPath:(nullable NSString *)outputPath
                               dylibPaths:(NSArray<NSString *> *)dylibPaths
                         removeDylibNames:(NSArray<NSString *> *)removeDylibNames
                                forceSign:(BOOL)forceSign
                               weakInject:(BOOL)weakInject
                         removeExtensions:(BOOL)removeExtensions
                           removeWatchApp:(BOOL)removeWatchApp
                   removeUISupportedDevices:(BOOL)removeUISupportedDevices
                          enableDocuments:(BOOL)enableDocuments
                              minOSVersion:(nullable NSString *)minOSVersion
                                  iconPath:(nullable NSString *)iconPath
                                    adHoc:(BOOL)adHoc
{
    NSString *resolvedOutput = outputPathForIPA(ipaPath, outputPath);
    std::vector<std::string> injectDylibs;
    std::vector<std::string> removeDylibs;

    for (NSString *path in dylibPaths) {
        if (path.length > 0) {
            injectDylibs.emplace_back(path.UTF8String);
        }
    }
    for (NSString *name in removeDylibNames) {
        if (name.length > 0) {
            removeDylibs.emplace_back(name.UTF8String);
        }
    }

    ZSignWrapperCPP wrapper;
    BOOL isAdhoc = adHoc || (certPath == nil && pkeyPath == nil);
    if (!wrapper.InitWithCert(
            certPath ? std::string(certPath.UTF8String) : "",
            pkeyPath ? std::string(pkeyPath.UTF8String) : "",
            provPath ? std::string(provPath.UTF8String) : "",
            password ? std::string(password.UTF8String) : "",
            entitlementsPath ? std::string(entitlementsPath.UTF8String) : "",
            isAdhoc,
            true
        ))
    {
        return [ZSignResult resultWithSuccess:NO
                                errorMessage:[NSString stringWithUTF8String:wrapper.GetLastError().c_str()]
                                  outputPath:nil];
    }

    bool success = wrapper.SignIPA(
        std::string(ipaPath.UTF8String),
        std::string(resolvedOutput.UTF8String),
        bundleId ? std::string(bundleId.UTF8String) : "",
        bundleVersion ? std::string(bundleVersion.UTF8String) : "",
        bundleName ? std::string(bundleName.UTF8String) : "",
        injectDylibs,
        removeDylibs,
        forceSign,
        weakInject,
        removeExtensions,
        removeWatchApp,
        removeUISupportedDevices,
        enableDocuments,
        minOSVersion ? std::string(minOSVersion.UTF8String) : "",
        iconPath ? std::string(iconPath.UTF8String) : ""
    );

    return [ZSignResult resultWithSuccess:success ? YES : NO
                             errorMessage:success ? nil : [NSString stringWithUTF8String:wrapper.GetLastError().c_str()]
                               outputPath:success ? resolvedOutput : nil];
}

+ (BOOL)signAppFolder:(NSString *)appFolderPath
           certPath:(nullable NSString *)certPath
           pkeyPath:(nullable NSString *)pkeyPath
           provPath:(nullable NSString *)provPath
           password:(nullable NSString *)password
           bundleId:(nullable NSString *)bundleId
         bundleName:(nullable NSString *)bundleName
      bundleVersion:(nullable NSString *)bundleVersion
              error:(NSError **)error
{
    ZSignWrapperCPP wrapper;
    
    BOOL isAdhoc = (certPath == nil && pkeyPath == nil);
    
    if (!wrapper.InitWithCert(
            certPath ? std::string([certPath UTF8String]) : "",
            pkeyPath ? std::string([pkeyPath UTF8String]) : "",
            provPath ? std::string([provPath UTF8String]) : "",
            password ? std::string([password UTF8String]) : "",
            "",
            isAdhoc,
            true
        ))
    {
        if (error) {
            *error = makeError([NSString stringWithUTF8String:wrapper.GetLastError().c_str()]);
        }
        return NO;
    }

    bool success = wrapper.SignAppFolder(
        std::string([appFolderPath UTF8String]),
        bundleId ? std::string([bundleId UTF8String]) : "",
        bundleVersion ? std::string([bundleVersion UTF8String]) : "",
        bundleName ? std::string([bundleName UTF8String]) : ""
    );

    if (!success) {
        if (error) {
            *error = makeError([NSString stringWithUTF8String:wrapper.GetLastError().c_str()]);
        }
        return NO;
    }

    return YES;
}

+ (nullable NSString *)extractIPAAtPath:(NSString *)ipaPath
                                  error:(NSError **)error
{
    NSString *extractPath = tempExtractFolder();
    
    // Create the extraction directory
    [[NSFileManager defaultManager] createDirectoryAtPath:extractPath
                              withIntermediateDirectories:YES
                                               attributes:nil
                                                    error:nil];
    
    if (!ZSignWrapperCPP::ExtractIPA(
            std::string([ipaPath UTF8String]),
            std::string([extractPath UTF8String])))
    {
        if (error) {
            *error = makeError(@"Failed to extract IPA archive.");
        }
        return nil;
    }
    
    return extractPath;
}

+ (BOOL)archivePayloadFolder:(NSString *)payloadFolderPath
                  toIPAAtPath:(NSString *)ipaPath
                       error:(NSError **)error
{
    if (!ZSignWrapperCPP::ArchiveIPA(
            std::string([payloadFolderPath UTF8String]),
            std::string([ipaPath UTF8String])))
    {
        if (error) {
            *error = makeError(@"Failed to archive IPA.");
        }
        return NO;
    }
    return YES;
}

+ (nullable NSDictionary *)certificateInfoFromP12:(NSString *)p12Path
                                         password:(nullable NSString *)password
                                           error:(NSError **)error
{
    // Read the p12 file
    NSData *p12Data = [NSData dataWithContentsOfFile:p12Path];
    if (!p12Data) {
        if (error) {
            *error = makeError(@"Could not read p12 file.");
        }
        return nil;
    }

    // Use Security framework to extract certificate info
    NSDictionary *options = @{
        (id)kSecImportExportPassphrase: password ?: @""
    };
    
    CFArrayRef items = NULL;
    OSStatus status = SecPKCS12Import((__bridge CFDataRef)p12Data,
                                       (__bridge CFDictionaryRef)options,
                                       &items);
    
    if (status != errSecSuccess || !items) {
        if (error) {
            NSString *errMsg = [NSString stringWithFormat:@"Failed to open p12 (status: %d)", (int)status];
            *error = makeError(errMsg);
        }
        if (items) CFRelease(items);
        return nil;
    }

    // Extract information from the first identity
    NSDictionary *dict = [(__bridge NSArray *)items firstObject];
    if (!dict) {
        if (items) CFRelease(items);
        if (error) {
            *error = makeError(@"No identities found in p12.");
        }
        return nil;
    }

    SecIdentityRef identity = (__bridge SecIdentityRef)dict[(id)kSecImportItemIdentity];
    SecCertificateRef certRef = NULL;
    SecIdentityCopyCertificate(identity, &certRef);
    
    if (!certRef) {
        if (items) CFRelease(items);
        if (error) {
            *error = makeError(@"Could not copy certificate from identity.");
        }
        return nil;
    }

    // Extract certificate details (iOS-compatible)
    CFStringRef summary = SecCertificateCopySubjectSummary(certRef);
    NSString *subjectSummary = (__bridge_transfer NSString *)summary;
    
    // Get common name
    CFStringRef commonName = NULL;
    SecCertificateCopyCommonName(certRef, &commonName);
    NSString *cn = commonName ? (__bridge_transfer NSString *)commonName : nil;

    // Pull commonly useful X.509 values while the Security certificate handle
    // is live. In particular, storing the actual not-after date prevents a
    // valid P12 from being shown as valid for a fabricated one-year period.
    NSArray *valueKeys = @[
        (__bridge id)kSecOIDX509V1ValidityNotAfter,
        (__bridge id)kSecOIDX509V1SerialNumber
    ];
    CFErrorRef valuesError = NULL;
    CFDictionaryRef valuesRef = SecCertificateCopyValues(
        certRef,
        (__bridge CFArrayRef)valueKeys,
        &valuesError
    );
    NSDictionary *certificateValues = valuesRef
        ? CFBridgingRelease(valuesRef)
        : @{};
    if (valuesError) {
        CFRelease(valuesError);
    }

    NSDictionary *expiryProperty = certificateValues[(__bridge id)kSecOIDX509V1ValidityNotAfter];
    NSDate *expirationDate = [expiryProperty[(id)kSecPropertyKeyValue] isKindOfClass:[NSDate class]]
        ? expiryProperty[(id)kSecPropertyKeyValue]
        : nil;

    NSDictionary *serialProperty = certificateValues[(__bridge id)kSecOIDX509V1SerialNumber];
    NSData *serialData = [serialProperty[(id)kSecPropertyKeyValue] isKindOfClass:[NSData class]]
        ? serialProperty[(id)kSecPropertyKeyValue]
        : nil;
    NSMutableString *serialNumber = [NSMutableString string];
    const unsigned char *serialBytes = (const unsigned char *)serialData.bytes;
    for (NSUInteger index = 0; index < serialData.length; index++) {
        [serialNumber appendFormat:@"%02X", serialBytes[index]];
    }
    
    CFRelease(certRef);
    CFRelease(items);

    NSMutableDictionary *result = [NSMutableDictionary dictionary];
    if (subjectSummary) {
        result[@"subject"] = subjectSummary;
    }
    if (cn) {
        result[@"commonName"] = cn;
    }
    if (expirationDate) {
        result[@"expirationDate"] = expirationDate;
    }
    if (serialNumber.length > 0) {
        result[@"serialNumber"] = serialNumber;
    }

    return [result copy];
}

@end
