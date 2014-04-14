//
//  CSAPISessionManager.m
//  Cloud66
//
//  The MIT License (MIT)
//
//  Copyright (c) 2013 Gabriel Rinaldi
//
//  Permission is hereby granted, free of charge, to any person obtaining a copy
//  of this software and associated documentation files (the "Software"), to deal
//  in the Software without restriction, including without limitation the rights
//  to use, copy, modify, merge, publish, distribute, sublicense, and/or sell
//  copies of the Software, and to permit persons to whom the Software is
//  furnished to do so, subject to the following conditions:
//
//  The above copyright notice and this permission notice shall be included in
//  all copies or substantial portions of the Software.
//
//  THE SOFTWARE IS PROVIDED "AS IS", WITHOUT WARRANTY OF ANY KIND, EXPRESS OR
//  IMPLIED, INCLUDING BUT NOT LIMITED TO THE WARRANTIES OF MERCHANTABILITY,
//  FITNESS FOR A PARTICULAR PURPOSE AND NONINFRINGEMENT. IN NO EVENT SHALL THE
//  AUTHORS OR COPYRIGHT HOLDERS BE LIABLE FOR ANY CLAIM, DAMAGES OR OTHER
//  LIABILITY, WHETHER IN AN ACTION OF CONTRACT, TORT OR OTHERWISE, ARISING FROM,
//  OUT OF OR IN CONNECTION WITH THE SOFTWARE OR THE USE OR OTHER DEALINGS IN
//  THE SOFTWARE.
//

#import <AFNetworking/AFNetworkActivityIndicatorManager.h>
#import "CSAPISessionManager.h"

NSString * const CSUserDidLoginNotification = @"CSUserDidLoginNotification";
NSString * const CSUserDidLogoutNotification = @"CSUserDidLogoutNotification";

static NSString * const kCSAPIBaseURLString = @"https://app.cloud66.com/api/2/";

#pragma mark CSAPISessionManager (Private)

@interface CSAPISessionManager ()

@property (strong, nonatomic, readonly) NSString *userAgent;
@property (strong, nonatomic, readonly) NSString *credentialsIdentifier;

@end

#pragma mark - CSAPISessionManager

@implementation CSAPISessionManager

#pragma mark - Getters/Setters

@synthesize credentialsIdentifier;
@synthesize userAgent;

- (BOOL)isAuthenticated {
    return ([AFOAuthCredential retrieveCredentialWithIdentifier:[self credentialsIdentifier] useICloud:NO] != nil);
}

- (NSString *)credentialsIdentifier {
    if (!credentialsIdentifier) {
        NSString *bundleID = [[NSBundle mainBundle] objectForInfoDictionaryKey:@"CFBundleIdentifier"];
        credentialsIdentifier = [NSString stringWithFormat:@"%@.oauth", bundleID];
    }

    return credentialsIdentifier;
}

- (NSString *)userAgent {
    if (!userAgent) {
        NSBundle *mainBundle = [NSBundle mainBundle];
        NSString *applicationName = [mainBundle objectForInfoDictionaryKey:@"CFBundleDisplayName"];
        NSString *versionNumber = [mainBundle objectForInfoDictionaryKey:@"CFBundleShortVersionString"];
        NSString *buildNumber = [mainBundle objectForInfoDictionaryKey:@"CFBundleVersion"];

        UIDevice *currentDevice = [UIDevice currentDevice];
        NSString *deviceModel = [currentDevice model];
        NSString *deviceSystemName = [[currentDevice systemName] stringByReplacingOccurrencesOfString:@"iPhone OS" withString:@"iOS"];
        NSString *deviceSystemVersion = [currentDevice systemVersion];

        NSString *locale = [[NSLocale currentLocale] localeIdentifier];
        CGFloat scale = [[UIScreen mainScreen] scale];

        userAgent = [[NSString alloc] initWithFormat:@"%@ %@/%@ (%@; %@ %@; Scale/%.2f; %@)", applicationName, versionNumber, buildNumber, deviceModel, deviceSystemName, deviceSystemVersion, scale, locale];
    }

    return userAgent;
}

#pragma mark - Shared client

+ (instancetype)sharedManager {
    static CSAPISessionManager *_sharedManager = nil;
    static dispatch_once_t onceToken;
    dispatch_once(&onceToken, ^{
        _sharedManager = [[CSAPISessionManager alloc] initWithBaseURL:[NSURL URLWithString:kCSAPIBaseURLString] clientID:CS_CLIENT_ID secret:CS_CLIENT_SECRET];
    });

    return _sharedManager;
}

#pragma mark - Authorize URL

+ (NSURL *)oauthAuthorizeURL {
    NSString *urlString = [NSString stringWithFormat:@"https://app.cloud66.com/oauth/authorize?client_id=%@&redirect_uri=%@&response_type=code&scope=%@", CS_CLIENT_ID, CS_REDIRECT_URI, CS_SCOPES];
    
    return [NSURL URLWithString:urlString];
}

#pragma mark - Initialization

- (id)initWithBaseURL:(NSURL *)url clientID:(NSString *)clientID secret:(NSString *)secret {
    self = [super initWithBaseURL:url clientID:clientID secret:secret];
    if (self) {
        [[AFNetworkActivityIndicatorManager sharedManager] setEnabled:YES];

        AFOAuthCredential *credential = [AFOAuthCredential retrieveCredentialWithIdentifier:[self credentialsIdentifier] useICloud:NO];
        if (credential) {
            [self setAuthorizationHeaderWithCredential:credential];
        }

        [[self requestSerializer] setValue:[self userAgent] forHTTPHeaderField:@"User-Agent"];
    }

    return self;
}

#pragma mark - Authentication

- (void)authenticateWithCode:(NSString *)aCode {
    [self authenticateUsingOAuthWithPath:@"/oauth/token" code:aCode redirectURI:CS_REDIRECT_URI success:^(AFOAuthCredential *credential) {
        if (credential) {
            [AFOAuthCredential storeCredential:credential withIdentifier:[self credentialsIdentifier] withAccessibility:(__bridge id)kSecAttrAccessibleAfterFirstUnlock useICloud:NO];

            [[UIApplication sharedApplication] registerForRemoteNotificationTypes:UIRemoteNotificationTypeAlert | UIRemoteNotificationTypeBadge | UIRemoteNotificationTypeSound];

            [[NSNotificationCenter defaultCenter] postNotificationName:CSUserDidLoginNotification object:self];
        } else {
            [self clearCredentials];
        }
    } failure:^(NSError *error) {
        [self clearCredentials];
    }];
}

- (void)logout {
    [self clearCredentials];

    [[NSNotificationCenter defaultCenter] postNotificationName:CSUserDidLogoutNotification object:self];
}

- (void)clearCredentials {
    NSManagedObjectContext *managedObjectContext = [CSAppDelegate managedObjectContext];
    NSPersistentStore *persistentStore = [[[managedObjectContext persistentStoreCoordinator] persistentStores] lastObject];
    NSURL *persistentStoreURL = [[persistentStore URL] URLByDeletingPathExtension];
    [[NSFileManager defaultManager] removeItemAtURL:[persistentStoreURL URLByAppendingPathExtension:@"sqlite"] error:nil];
    [[NSFileManager defaultManager] removeItemAtURL:[persistentStoreURL URLByAppendingPathExtension:@"sqlite-shm"] error:nil];
    [[NSFileManager defaultManager] removeItemAtURL:[persistentStoreURL URLByAppendingPathExtension:@"sqlite-wal"] error:nil];

    [(CSAppDelegate *)[[UIApplication sharedApplication] delegate] resetContext];

    [[self requestSerializer] clearAuthorizationHeader];

    [AFOAuthCredential deleteCredentialWithIdentifier:[self credentialsIdentifier] useICloud:NO];

    for (NSHTTPCookie *cookie in [[NSHTTPCookieStorage sharedHTTPCookieStorage] cookies]) {
        [[NSHTTPCookieStorage sharedHTTPCookieStorage] deleteCookie:cookie];
    }
}

@end
