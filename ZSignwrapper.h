// ZSignwrapper.h
// Obj-C wrapper for Zsign signing engine
// Copyright (c) 2026 FreeSign

#import <Foundation/Foundation.h>

NS_ASSUME_NONNULL_BEGIN

/// Result object returned from signing operations
@interface ZSignResult : NSObject

@property (nonatomic, assign) BOOL success;
@property (nonatomic, copy, nullable) NSString *errorMessage;
@property (nonatomic, copy, nullable) NSString *outputPath;

+ (instancetype)resultWithSuccess:(BOOL)success
                     errorMessage:(nullable NSString *)errorMessage
                       outputPath:(nullable NSString *)outputPath;

@end

/// Main signing interface wrapping Zsign's C++ engine
@interface ZSignWrapper : NSObject

/// Sign an IPA file with the given certificate and provisioning profile.
/// @param ipaPath Path to the input IPA file
/// @param certPath Path to the certificate (PEM or DER), or nil for ad-hoc
/// @param pkeyPath Path to the private key (PEM or DER, or p12), or nil for ad-hoc
/// @param provPath Path to the .mobileprovision file
/// @param password Password for the private key/p12 (or nil if none)
/// @param bundleId New bundle ID to override (or nil to keep original)
/// @param bundleName New display name (or nil to keep original)
/// @param bundleVersion New version string (or nil to keep original)
/// @param outputPath Path for the signed IPA output (or nil for automatic temp path)
/// @return A ZSignResult with success/failure info
+ (ZSignResult *)signIPAAtPath:(NSString *)ipaPath
                    certPath:(nullable NSString *)certPath
                    pkeyPath:(nullable NSString *)pkeyPath
                    provPath:(nullable NSString *)provPath
                    password:(nullable NSString *)password
                    bundleId:(nullable NSString *)bundleId
                  bundleName:(nullable NSString *)bundleName
               bundleVersion:(nullable NSString *)bundleVersion
                  outputPath:(nullable NSString *)outputPath;

/// Sign an IPA while applying the supported FreeSign bundle and dylib options.
/// The output path must be inside the app container.
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
                                    adHoc:(BOOL)adHoc;

/// Sign an already-extracted .app folder.
+ (BOOL)signAppFolder:(NSString *)appFolderPath
           certPath:(nullable NSString *)certPath
           pkeyPath:(nullable NSString *)pkeyPath
           provPath:(nullable NSString *)provPath
           password:(nullable NSString *)password
           bundleId:(nullable NSString *)bundleId
         bundleName:(nullable NSString *)bundleName
      bundleVersion:(nullable NSString *)bundleVersion
              error:(NSError **)error;

/// Extract an IPA to a temporary folder.
/// @return The extraction path, or nil on failure.
+ (nullable NSString *)extractIPAAtPath:(NSString *)ipaPath
                                  error:(NSError **)error;

/// Archive a Payload folder to an IPA.
+ (BOOL)archivePayloadFolder:(NSString *)payloadFolderPath
                  toIPAAtPath:(NSString *)ipaPath
                       error:(NSError **)error;

/// Get the signing certificate information from a p12 file.
/// @return A dictionary with cert info, or nil on failure.
+ (nullable NSDictionary *)certificateInfoFromP12:(NSString *)p12Path
                                         password:(nullable NSString *)password
                                           error:(NSError **)error;

@end

NS_ASSUME_NONNULL_END
