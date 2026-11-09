// Google sign-in / keychain fixes for re-signed (sideloaded) YouTube.
// Adapted from uYouEnhanced (Sources/uYouPlusPatches.xm, gSideloadingPatches).

#import <Foundation/Foundation.h>
#import <Security/Security.h>

#define YT_BUNDLE_ID @"com.google.ios.youtube"
#define YT_NAME @"YouTube"

// The keychain access group our re-signed app actually has (team-prefixed).
static NSString *accessGroupID(void) {
    static NSString *group;
    static dispatch_once_t once;
    dispatch_once(&once, ^{
        NSDictionary *query = @{
            (__bridge id)kSecClass: (__bridge id)kSecClassGenericPassword,
            (__bridge id)kSecAttrAccount: @"bundleSeedID",
            (__bridge id)kSecAttrService: @"",
            (__bridge id)kSecReturnAttributes: @YES,
        };
        CFDictionaryRef result = NULL;
        OSStatus status = SecItemCopyMatching((__bridge CFDictionaryRef)query, (CFTypeRef *)&result);
        if (status == errSecItemNotFound)
            status = SecItemAdd((__bridge CFDictionaryRef)query, (CFTypeRef *)&result);
        if (status == errSecSuccess && result) {
            group = [(__bridge NSDictionary *)result objectForKey:(__bridge id)kSecAttrAccessGroup];
            CFRelease(result);
        }
    });
    return group;
}

@interface SSOConfiguration : NSObject
@end

// App groups are unavailable to free signing; redirect to a folder in Documents.
%hook NSFileManager
- (NSURL *)containerURLForSecurityApplicationGroupIdentifier:(NSString *)groupIdentifier {
    if (groupIdentifier != nil) {
        NSURL *docs = [[[NSFileManager defaultManager] URLsForDirectory:NSDocumentDirectory inDomains:NSUserDomainMask] lastObject];
        return [docs URLByAppendingPathComponent:@"AppGroup"];
    }
    return %orig;
}
%end

// Report the real app identity to Google's libraries.
%hook YTVersionUtils
+ (NSString *)appName { return YT_NAME; }
+ (NSString *)appID { return YT_BUNDLE_ID; }
%end
%hook GCKBUtils
+ (NSString *)appIdentifier { return YT_BUNDLE_ID; }
%end
%hook GPCDeviceInfo
+ (NSString *)bundleId { return YT_BUNDLE_ID; }
%end
%hook OGLBundle
+ (NSString *)shortAppName { return YT_NAME; }
%end
%hook GVROverlayView
+ (NSString *)appName { return YT_NAME; }
%end
%hook OGLPhenotypeFlagServiceImpl
- (NSString *)bundleId { return YT_BUNDLE_ID; }
%end
%hook APMAEU
+ (BOOL)isFAS { return YES; }
%end
%hook GULAppEnvironmentUtil
+ (BOOL)isFromAppStore { return YES; }
%end
%hook SSOClientLogin
+ (NSString *)defaultSourceString { return YT_BUNDLE_ID; }
%end
%hook SSOConfiguration
- (id)initWithClientID:(id)clientID supportedAccountServices:(id)services {
    self = %orig;
    @try {
        [self setValue:YT_NAME forKey:@"_shortAppName"];
        [self setValue:YT_BUNDLE_ID forKey:@"_applicationIdentifier"];
    } @catch (NSException *e) {}
    return self;
}
%end

// Point every keychain user at our real access group.
%hook SSOKeychainHelper
+ (id)accessGroup { return accessGroupID(); }
+ (id)sharedAccessGroup { return accessGroupID(); }
%end
%hook SSOFolsomKeychainUtils
- (id)sharedAccessGroup { return accessGroupID(); }
%end
%hook GULKeychainStorage
- (void)getObjectForKey:(id)key objectClass:(Class)cls accessGroup:(id)group completionHandler:(id)handler {
    %orig(key, cls, accessGroupID(), handler);
}
- (void)setObject:(id)object forKey:(id)key accessGroup:(id)group completionHandler:(id)handler {
    %orig(object, key, accessGroupID(), handler);
}
- (void)removeObjectForKey:(id)key accessGroup:(id)group completionHandler:(id)handler {
    %orig(key, accessGroupID(), handler);
}
- (void)getObjectFromKeychainForKey:(id)key objectClass:(Class)cls accessGroup:(id)group completionHandler:(id)handler {
    %orig(key, cls, accessGroupID(), handler);
}
- (id)keychainQueryWithKey:(id)key accessGroup:(id)group {
    return %orig(key, accessGroupID());
}
%end
%hook GNPEncryptionConfiguration
- (id)initWithKeychainAccessGroup:(id)group { return %orig(accessGroupID()); }
- (id)keychainAccessGroup { return accessGroupID(); }
%end
%hook FIRInstallationsStore
- (id)initWithSecureStorage:(id)storage accessGroup:(id)group { return %orig(storage, accessGroupID()); }
- (id)accessGroup { return accessGroupID(); }
%end
%hook CHMConfiguration
- (void)setKeychainAccessGroup:(id)group { %orig(accessGroupID()); }
- (id)keychainAccessGroup { return accessGroupID(); }
%end
