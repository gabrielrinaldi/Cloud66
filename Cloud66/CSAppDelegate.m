//
//  CSAppDelegate.m
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

#import <Appirater/Appirater.h>
#import <CocoaLumberjack/DDASLLogger.h>
#import <CocoaLumberjack/DDTTYLogger.h>
#import <CSNotificationView/CSNotificationView.h>
#import <HockeySDK/HockeySDK.h>
#import <HockeySDK/BITFeedbackManagerPrivate.h>
#import "Stack.h"
#import "CSAppearanceManager.h"
#import "CSAPISessionManager.h"
#import "LoginViewController.h"
#import "StacksViewController.h"

NSString * const CSFailedToRegisterForRemoteNotificationsNotification = @"CSFailedToRegisterForRemoteNotificationsNotification";

#pragma mark CSAppDelegate (Private)

@interface CSAppDelegate () <AppiraterDelegate, BITHockeyManagerDelegate>

@end

#pragma mark - CSAppDelegate

@implementation CSAppDelegate

#pragma mark - Getters/Setters

@synthesize window = _window;
@synthesize navigationController = _navigationController;
@synthesize managedObjectContext = _managedObjectContext;
@synthesize managedObjectModel = _managedObjectModel;
@synthesize persistentStoreCoordinator = _persistentStoreCoordinator;

#pragma mark - Application lifecycle

- (BOOL)application:(UIApplication *)application didFinishLaunchingWithOptions:(NSDictionary *)launchOptions {
    [[BITHockeyManager sharedHockeyManager] configureWithBetaIdentifier:CS_HOCKEY_APP_BETA_IDENTIFIER liveIdentifier:CS_HOCKEY_APP_IDENTIFIER delegate:self];
#ifdef APPSTORE
    [[BITHockeyManager sharedHockeyManager] setEnableStoreUpdateManager:YES];
#endif
    [[[BITHockeyManager sharedHockeyManager] feedbackManager] setRequireUserEmail:BITFeedbackUserDataElementRequired];
    [[[BITHockeyManager sharedHockeyManager] feedbackManager] setRequireUserName:BITFeedbackUserDataElementRequired];
    [[BITHockeyManager sharedHockeyManager] startManager];


    [Mixpanel sharedInstanceWithToken:CS_MIXPANEL_TOKEN];

    [[Mixpanel sharedInstance] identify:[[[UIDevice currentDevice] identifierForVendor] UUIDString]];

    [DDLog addLogger:[DDASLLogger sharedInstance]];
    [DDLog addLogger:[DDTTYLogger sharedInstance]];
    [[DDTTYLogger sharedInstance] setColorsEnabled:YES];

    [[NSNotificationCenter defaultCenter] addObserver:self selector:@selector(userDidLogout) name:CSUserDidLogoutNotification object:nil];

    [Appirater setAppId:@"642299804"];
    [Appirater setDaysUntilPrompt:5];
    [Appirater setUsesUntilPrompt:10];
    [Appirater setSignificantEventsUntilPrompt:5];
    [Appirater setTimeBeforeReminding:5];
    [Appirater appLaunched:YES];

    if ([[NSUserDefaults standardUserDefaults] boolForKey:FETCH_KEY]) {
        [[UIApplication sharedApplication] setMinimumBackgroundFetchInterval:UIApplicationBackgroundFetchIntervalMinimum];
    }

    if ([[NSUserDefaults standardUserDefaults] objectForKey:TOKEN_KEY]) {
        [[UIApplication sharedApplication] registerForRemoteNotificationTypes:UIRemoteNotificationTypeAlert | UIRemoteNotificationTypeBadge | UIRemoteNotificationTypeSound];
    }

    UIWindow *window = [[UIWindow alloc] initWithFrame:[[UIScreen mainScreen] bounds]];
    [window setBackgroundColor:[UIColor whiteColor]];
    [window setTintColor:[[CSAppearanceManager defaultManager] tintColor]];
    [self setWindow:window];

    StacksViewController *stacksViewController = [[StacksViewController alloc] initWithNibName:@"StacksViewController" bundle:nil];

    UINavigationController *navigationController = [[UINavigationController alloc] initWithRootViewController:stacksViewController];
    [self setNavigationController:navigationController];

    [[self window] setRootViewController:navigationController];
    [[self window] makeKeyAndVisible];

    if (![[CSAPISessionManager sharedManager] isAuthenticated]) {
        [LoginViewController showAnimated:NO];
    }

    return YES;
}

- (void)applicationDidBecomeActive:(UIApplication *)application {
    [[Mixpanel sharedInstance] track:@"App Open"];

    if ([[NSUserDefaults standardUserDefaults] objectForKey:TOKEN_KEY]) {
        [[UIApplication sharedApplication] registerForRemoteNotificationTypes:UIRemoteNotificationTypeAlert | UIRemoteNotificationTypeBadge | UIRemoteNotificationTypeSound];
    }
}

- (void)applicationWillEnterForeground:(UIApplication *)application {
    [Appirater appEnteredForeground:YES];
}

#pragma mark - Push notifications

- (void)application:(UIApplication *)application didRegisterForRemoteNotificationsWithDeviceToken:(NSData *)deviceToken {
    [[[Mixpanel sharedInstance] people] addPushDeviceToken:deviceToken];

    NSString *model = @"1";
    NSString *deviceModel = [[UIDevice currentDevice] model];
    if ([deviceModel rangeOfString:@"iPod"].location != NSNotFound) {
        model = @"3";
    } else if ([deviceModel rangeOfString:@"iPad"].location != NSNotFound) {
        model = @"2";
    }

    NSMutableString *token = [NSMutableString stringWithFormat:@"%@", deviceToken];
    NSRegularExpression *regex = [NSRegularExpression regularExpressionWithPattern:@"[< >]" options:0 error:nil];
    [regex replaceMatchesInString:token options:0 range:NSMakeRange(0, [token length]) withTemplate:@""];
    [[NSUserDefaults standardUserDefaults] setObject:token forKey:TOKEN_KEY];

    [[CSAPISessionManager sharedManager] POST:@"users/devices" parameters:@{ @"device_type" : @"1", @"sub_type" : model, @"token" : token } success:nil failure:^(NSURLSessionDataTask *task, NSError *error) {
        [[NSNotificationCenter defaultCenter] postNotificationName:CSFailedToRegisterForRemoteNotificationsNotification object:error];

        [[Mixpanel sharedInstance] trackErrorInClass:[[CSAppDelegate class] description] function:__PRETTY_FUNCTION__ line:__LINE__ type:[NSString stringWithFormat:@"HTTP-%d", [error code]]];
    }];
}

- (void)application:(UIApplication *)application didFailToRegisterForRemoteNotificationsWithError:(NSError *)error {
    [[NSNotificationCenter defaultCenter] postNotificationName:CSFailedToRegisterForRemoteNotificationsNotification object:error];

    if ([error code] == 3010) {
        return;
    }

    [[NSUserDefaults standardUserDefaults] setObject:@"retry" forKey:TOKEN_KEY];

    [[Mixpanel sharedInstance] trackErrorInClass:[[CSAppDelegate class] description] function:__PRETTY_FUNCTION__ line:__LINE__ type:[NSString stringWithFormat:@"Push-%d", [error code]]];
}

- (void)application:(UIApplication *)application didReceiveRemoteNotification:(NSDictionary *)userInfo fetchCompletionHandler:(void (^)(UIBackgroundFetchResult))completionHandler {
    UIViewController *viewController = [[[self navigationController] viewControllers] lastObject];
    [CSNotificationView showInViewController:viewController tintColor:[[CSAppearanceManager defaultManager] tintColor] image:nil message:[[userInfo objectForKey:@"aps"] objectForKey:@"alert"] duration:2.0];

    [[Mixpanel sharedInstance] track:@"Push Notification" properties:userInfo];

    [Stack syncWithSuccess:^(BOOL hasNewData){
        if (hasNewData) {
            completionHandler(UIBackgroundFetchResultNewData);
        } else {
            completionHandler(UIBackgroundFetchResultNoData);
        }
    } failure:^(NSError *error) {
        completionHandler(UIBackgroundFetchResultFailed);
    }];
}

#pragma mark - URL handling

- (BOOL)application:(UIApplication *)application openURL:(NSURL *)url sourceApplication:(NSString *)sourceApplication annotation:(id)annotation {
    NSMutableDictionary *properties = [NSMutableDictionary dictionary];
    if (sourceApplication) {
        [properties setObject:sourceApplication forKey:@"Source Application"];
    }

    if (url) {
        [properties setObject:[url absoluteString] forKey:@"URL"];
    }

    [[Mixpanel sharedInstance] track:@"Open URL" properties:properties];

    if ([[url host] isEqualToString:@"oauth"]) {
        NSString *code = [[url query] substringFromIndex:5];
        [[CSAPISessionManager sharedManager] authenticateWithCode:code];

        return YES;
    }

    return NO;
}

#pragma mark - Background fetch

-(void)application:(UIApplication *)application performFetchWithCompletionHandler:(void (^)(UIBackgroundFetchResult))completionHandler {
    [Stack syncWithSuccess:^(BOOL hasNewData){
        if (hasNewData) {
            completionHandler(UIBackgroundFetchResultNewData);
        } else {
            completionHandler(UIBackgroundFetchResultNoData);
        }
    } failure:^(NSError *error) {
        completionHandler(UIBackgroundFetchResultFailed);
    }];
}

#pragma mark - App rating

- (void)appiraterDidDisplayAlert:(Appirater *)appirater {
    [[Mixpanel sharedInstance] track:@"Rate app" properties:@{ @"Type" : @"Auto" }];
}

- (void)appiraterDidDeclineToRate:(Appirater *)appirater {
    [[Mixpanel sharedInstance] track:@"Rate app" properties:@{ @"Result" : @"Decline" }];
}

- (void)appiraterDidOptToRate:(Appirater *)appirater {
    [[Mixpanel sharedInstance] track:@"Rate app" properties:@{ @"Result" : @"Rate" }];
}

- (void)appiraterDidOptToRemindLater:(Appirater *)appirater {
    [[Mixpanel sharedInstance] track:@"Rate app" properties:@{ @"Result" : @"Remind me" }];
}

#pragma mark - Authentication handling

- (void)userDidLogout {
    [[Mixpanel sharedInstance] track:@"Logout"];

    [LoginViewController show];
}

#pragma mark - Core Data stack

- (void)resetContext {
    _managedObjectContext = nil;
    _managedObjectModel = nil;
    _persistentStoreCoordinator = nil;
}

- (void)updateContext:(NSNotification *)notification {
    NSManagedObjectContext *managedObjectContext = [self managedObjectContext];
    if ([notification object] == managedObjectContext) {
        return;
    }

    if (![NSThread isMainThread]) {
        [self performSelectorOnMainThread:@selector(updateContext:) withObject:notification waitUntilDone:YES];

        return;
    }

    [managedObjectContext mergeChangesFromContextDidSaveNotification:notification];
}

- (NSManagedObjectContext *)managedObjectContext {
    if (!_managedObjectContext) {
        NSPersistentStoreCoordinator *coordinator = [self persistentStoreCoordinator];
        if (coordinator) {
            _managedObjectContext = [[NSManagedObjectContext alloc] initWithConcurrencyType:NSMainQueueConcurrencyType];
            [_managedObjectContext setPersistentStoreCoordinator:coordinator];

            [[NSNotificationCenter defaultCenter] addObserver:self selector:@selector(updateContext:) name:NSManagedObjectContextDidSaveNotification object:nil];
        }
    }

    return _managedObjectContext;
}

- (NSManagedObjectModel *)managedObjectModel {
    if (!_managedObjectModel) {
        NSURL *modelURL = [[NSBundle mainBundle] URLForResource:@"Cloud66" withExtension:@"momd"];
        _managedObjectModel = [[NSManagedObjectModel alloc] initWithContentsOfURL:modelURL];
    }

    return _managedObjectModel;
}

- (NSPersistentStoreCoordinator *)persistentStoreCoordinator {
    if (!_persistentStoreCoordinator) {
        NSURL *storeURL = [[CSAppDelegate applicationDocumentsDirectory] URLByAppendingPathComponent:@"Cloud66.sqlite"];

        NSError *error = nil;
        _persistentStoreCoordinator = [[NSPersistentStoreCoordinator alloc] initWithManagedObjectModel:[self managedObjectModel]];
        if (![_persistentStoreCoordinator addPersistentStoreWithType:NSSQLiteStoreType configuration:nil URL:storeURL options:nil error:&error]) {
            [[NSFileManager defaultManager] removeItemAtURL:storeURL error:nil];

            error = nil;
            if (![_persistentStoreCoordinator addPersistentStoreWithType:NSSQLiteStoreType configuration:nil URL:storeURL options:nil error:&error]) {

                DDLogError(@"Unresolved error %@, %@", error, [error userInfo]);
                abort();
            }
        }
    }
    
    return _persistentStoreCoordinator;
}

#pragma mark - Helpers

+ (NSManagedObjectContext *)managedObjectContext {
    CSAppDelegate *appDelegate = (CSAppDelegate *)[[UIApplication sharedApplication] delegate];

    return [appDelegate managedObjectContext];
}

+ (NSURL *)applicationDocumentsDirectory {
    return [[[NSFileManager defaultManager] URLsForDirectory:NSDocumentDirectory inDomains:NSUserDomainMask] lastObject];
}

@end
