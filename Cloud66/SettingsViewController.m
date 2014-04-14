//
//  SettingsViewController.m
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

#import "CSAppearanceManager.h"
#import "CSAPISessionManager.h"
#import "SettingsViewController.h"

@import MessageUI;

static NSString *kSettingsCellIdentifier = @"kSettingsCellIdentifier";
static NSString *kSettingsSwitchCellIdentifier = @"kSettingsSwitchCellIdentifier";

#pragma mark SettingsViewController (Private)

@interface SettingsViewController () <MFMailComposeViewControllerDelegate>

@property (strong, nonatomic, readonly) NSArray *sections;
@property (strong, nonatomic, readonly) UISwitch *notificationSwitch;
@property (strong, nonatomic, readonly) UISwitch *fetchSwitch;

@end

#pragma mark - SettingsViewController

@implementation SettingsViewController

#pragma mark - Getters/Setters

@synthesize sections;
@synthesize notificationSwitch;
@synthesize fetchSwitch;

- (NSArray *)sections {
    NSMutableArray *mutableSections = [NSMutableArray array];

    NSDictionary *notifications = @{
                                    @"title" : NSLocalizedString(@"NotificationsTitle", @"Settings"),
                                    @"rows" : @[
                                                @{
                                                    @"icon" : @"NotificationIcon",
                                                    @"title" : NSLocalizedString(@"NotificationToggle", @"Settings"),
                                                    @"type" : @"notification",
                                                    @"selector" : @"toggleNotifications:"
                                                },
                                                @{
                                                    @"icon" : @"BackgroundRefreshIcon",
                                                    @"title" : NSLocalizedString(@"BackgroundRefreshToggle", @"Settings"),
                                                    @"type" : @"fetch",
                                                    @"selector" : @"toggleBackgroundRefresh:"
                                                }
                                            ]
                                    };
    [mutableSections addObject:notifications];

    NSDictionary *feedback = @{
                                    @"title" : NSLocalizedString(@"FeedbackTitle", @"Settings"),
                                    @"rows" : @[
                                            @{
                                                @"icon" : @"ReportIcon",
                                                @"title" : NSLocalizedString(@"ReportIssue", @"Settings"),
                                                @"type" : @"action",
                                                @"selector" : @"reportIssue"
                                                }
                                            ]
                                    };
    [mutableSections addObject:feedback];

    NSDictionary *authentication = @{
                               @"rows" : @[
                                       @{
                                           @"title" : NSLocalizedString(@"SignOut", @"Settings"),
                                           @"type" : @"destructive",
                                           @"selector" : @"signOut"
                                           }
                                       ]
                               };
    [mutableSections addObject:authentication];

    return [NSArray arrayWithArray:mutableSections];
}

#pragma mark - Observers

- (void)updateSwitch {
    if ([self notificationSwitch]) {
        [[self notificationSwitch] setOn:NO animated:YES];
    }
}

#pragma mark - Buttons actions

- (void)close {
    [self dismissViewControllerAnimated:YES completion:nil];
}

- (void)toggleNotifications:(UISwitch *)aSwitch {
    [[Mixpanel sharedInstance] track:@"Push Notifications" properties:@{ @"Enabled" : [NSNumber numberWithBool:[aSwitch isOn]] }];

    if ([aSwitch isOn]) {
        [[UIApplication sharedApplication] registerForRemoteNotificationTypes:UIRemoteNotificationTypeAlert | UIRemoteNotificationTypeBadge | UIRemoteNotificationTypeSound];
    } else {
        NSUserDefaults *userDefaults = [NSUserDefaults standardUserDefaults];
        NSString *token = [userDefaults objectForKey:TOKEN_KEY];
        if ([token isEqualToString:@"retry"]) {
            [userDefaults removeObjectForKey:TOKEN_KEY];
        } else {
            [[CSAPISessionManager sharedManager] DELETE:[NSString stringWithFormat:@"users/devices/%@", token] parameters:nil success:^(NSURLSessionDataTask *task, id responseObject) {
                [userDefaults removeObjectForKey:TOKEN_KEY];
            } failure:^(NSURLSessionDataTask *task, NSError *error) {
                if (aSwitch) {
                    [aSwitch setOn:YES animated:YES];
                }
            }];
        }
    }
}

- (void)toggleBackgroundRefresh:(UISwitch *)aSwitch {
    [[NSUserDefaults standardUserDefaults] setBool:[aSwitch isOn] forKey:FETCH_KEY];

    [[Mixpanel sharedInstance] track:@"Background Refresh" properties:@{ @"Enabled" : [NSNumber numberWithBool:[aSwitch isOn]] }];

    if ([aSwitch isOn]) {
        [[UIApplication sharedApplication] setMinimumBackgroundFetchInterval:UIApplicationBackgroundFetchIntervalMinimum];
    } else {
        [[UIApplication sharedApplication] setMinimumBackgroundFetchInterval:UIApplicationBackgroundFetchIntervalNever];
    }
}

- (void)reportIssue {
    if (![MFMailComposeViewController canSendMail]) {
        [[Mixpanel sharedInstance] track:@"Cannot send email"];
        
        return;
    }
    
    [[Mixpanel sharedInstance] track:@"Report issue"];
    
    MFMailComposeViewController *mailComposeViewController = [[MFMailComposeViewController alloc] init];
    mailComposeViewController.mailComposeDelegate = self;
    [mailComposeViewController setToRecipients:@[ @"hi@gabrielrinaldi.me" ]];
    [mailComposeViewController setSubject:NSLocalizedString(@"ReportIssue", @"Settings")];
    
    if (mailComposeViewController) {
        [self presentViewController:mailComposeViewController animated:YES completion:nil];
    }
}

- (void)signOut {
    [[CSAPISessionManager sharedManager] logout];
}
    
#pragma mark - Mail composer delegate
    
- (void)mailComposeController:(MFMailComposeViewController*)controller didFinishWithResult:(MFMailComposeResult)result error:(NSError*)error {
    if (result == MFMailComposeResultSent) {
        [[Mixpanel sharedInstance] track:@"Issue reported"];
    }
    
    [controller dismissViewControllerAnimated:YES completion:nil];
}

#pragma mark - Table view data source

- (NSInteger)numberOfSectionsInTableView:(UITableView *)tableView {
    return [[self sections] count];
}

- (UIView *)tableView:(UITableView *)tableView viewForHeaderInSection:(NSInteger)section {
    NSDictionary *sectionDictionary = [[self sections] objectAtIndex:section];

    float height = [self tableView:tableView heightForHeaderInSection:section];

    UIView *titleView = [[UIView alloc] initWithFrame:CGRectMake(0, 0, 320, height)];

    UILabel *titleLabel = [[UILabel alloc] initWithFrame:CGRectMake(15, 0, 290, height)];
    [titleLabel setText:[[sectionDictionary objectForKey:@"title"] uppercaseString]];
    [titleLabel setTextColor:[[CSAppearanceManager defaultManager] lightTextColor]];

    [titleLabel setFont:[UIFont preferredFontForTextStyle:UIFontTextStyleSubheadline]];
    [titleView addSubview:titleLabel];

    return titleView;
}

- (CGFloat)tableView:(UITableView *)tableView heightForHeaderInSection:(NSInteger)section {
    NSDictionary *sectionDictionary = [[self sections] objectAtIndex:section];

    if (![sectionDictionary objectForKey:@"title"]) {
        return 0;
    }

    static UILabel *settingsHeightLabel;
    if (!settingsHeightLabel) {
        settingsHeightLabel = [[UILabel alloc] initWithFrame:CGRectMake(0, 0, FLT_MAX, FLT_MAX)];
        [settingsHeightLabel setText:@"TEST"];
    }

    [settingsHeightLabel setFont:[UIFont preferredFontForTextStyle:UIFontTextStyleHeadline]];
    [settingsHeightLabel sizeToFit];

    return (int)(settingsHeightLabel.frame.size.height * 1.7);
}

- (NSInteger)tableView:(UITableView *)tableView numberOfRowsInSection:(NSInteger)section {
    NSDictionary *sectionDictionary = [[self sections] objectAtIndex:section];

    return [[sectionDictionary objectForKey:@"rows"] count];
}

- (UITableViewCell *)tableView:(UITableView *)tableView cellForRowAtIndexPath:(NSIndexPath *)indexPath {
    NSDictionary *sectionDictionary = [self sections][indexPath.section];
    NSDictionary *rowDictionary = sectionDictionary[@"rows"][indexPath.row];

    UITableViewCell *cell;
    if ([rowDictionary[@"type"] isEqualToString:@"notification"] || [rowDictionary[@"type"] isEqualToString:@"fetch"]) {
        cell = [tableView dequeueReusableCellWithIdentifier:kSettingsSwitchCellIdentifier];
        [cell setSelectionStyle:UITableViewCellSelectionStyleNone];
    } else {
        cell = [tableView dequeueReusableCellWithIdentifier:kSettingsCellIdentifier];
        [cell setSelectionStyle:UITableViewCellSelectionStyleDefault];
    }

    NSString *icon = [rowDictionary objectForKey:@"icon"];
    if (icon) {
        [[cell imageView] setImage:[UIImage imageNamed:icon]];
    } else {
        [[cell imageView] setImage:nil];
    }

    [[cell textLabel] setText:[rowDictionary objectForKey:@"title"]];

    if ([rowDictionary[@"type"] isEqualToString:@"notification"]) {
        UISwitch *cellSwitch = [UISwitch new];
        [cellSwitch setOnTintColor:[[CSAppearanceManager defaultManager] tintColor]];
        [cellSwitch addTarget:self action:NSSelectorFromString([rowDictionary objectForKey:@"selector"]) forControlEvents:UIControlEventValueChanged];
        if ([[NSUserDefaults standardUserDefaults] objectForKey:TOKEN_KEY]) {
            [cellSwitch setOn:YES animated:NO];
        }
        notificationSwitch = cellSwitch;
        [cell setAccessoryView:cellSwitch];
        [cell setBackgroundColor:[UIColor whiteColor]];
        [[cell textLabel] setTextColor:[[CSAppearanceManager defaultManager] darkTextColor]];
        [[cell textLabel] setTextAlignment:NSTextAlignmentLeft];
        [[cell textLabel] setFont:[UIFont preferredFontForTextStyle:UIFontTextStyleHeadline]];
    } if ([rowDictionary[@"type"] isEqualToString:@"fetch"]) {
        UISwitch *cellSwitch = [UISwitch new];
        [cellSwitch setOnTintColor:[[CSAppearanceManager defaultManager] tintColor]];
        [cellSwitch addTarget:self action:NSSelectorFromString([rowDictionary objectForKey:@"selector"]) forControlEvents:UIControlEventValueChanged];
        if ([[NSUserDefaults standardUserDefaults] boolForKey:FETCH_KEY]) {
            [cellSwitch setOn:YES animated:NO];
        }
        fetchSwitch = cellSwitch;
        [cell setAccessoryView:cellSwitch];
        [cell setBackgroundColor:[UIColor whiteColor]];
        [[cell textLabel] setTextColor:[[CSAppearanceManager defaultManager] darkTextColor]];
        [[cell textLabel] setTextAlignment:NSTextAlignmentLeft];
        [[cell textLabel] setFont:[UIFont preferredFontForTextStyle:UIFontTextStyleHeadline]];
    } else if ([rowDictionary[@"type"] isEqualToString:@"destructive"]) {
        [cell setAccessoryType:UITableViewCellAccessoryNone];
        [cell setBackgroundColor:[[CSAppearanceManager defaultManager] redColor]];
        [[cell textLabel] setTextColor:[UIColor whiteColor]];
        [[cell textLabel] setTextAlignment:NSTextAlignmentCenter];
        [[cell textLabel] setFont:[UIFont preferredFontForTextStyle:UIFontTextStyleHeadline]];
    } else {
        [cell setAccessoryType:UITableViewCellAccessoryNone];
        [cell setBackgroundColor:[UIColor whiteColor]];
        [[cell textLabel] setTextColor:[[CSAppearanceManager defaultManager] darkTextColor]];
        [[cell textLabel] setTextAlignment:NSTextAlignmentLeft];
        [[cell textLabel] setFont:[UIFont preferredFontForTextStyle:UIFontTextStyleHeadline]];
    }

    return cell;
}

#pragma mark - Table view delegate

- (void)tableView:(UITableView *)tableView didSelectRowAtIndexPath:(NSIndexPath *)indexPath {
    [tableView deselectRowAtIndexPath:indexPath animated:YES];

    NSDictionary *sectionDictionary = [[self sections] objectAtIndex:indexPath.section];
    NSDictionary *rowDictionary = [[sectionDictionary objectForKey:@"rows"] objectAtIndex:indexPath.row];

    NSString *type = [rowDictionary objectForKey:@"type"];
    if ([type isEqualToString:@"action"] || [type isEqualToString:@"destructive"]) {
        SuppressPerformSelectorLeakWarning(
                                           [self performSelector:NSSelectorFromString([rowDictionary objectForKey:@"selector"])];
                                           );
    }
}

#pragma mark - Font size delegate

- (void)preferredContentSizeChanged:(NSNotification *)notification {
    UILabel *footerLabel = (UILabel *)[[self tableView] tableFooterView];
    [footerLabel setFont:[UIFont preferredFontForTextStyle:UIFontTextStyleFootnote]];

    [[self tableView] reloadData];
}

#pragma mark - View lifecycle

- (void)viewDidLoad {
    [super viewDidLoad];

    [[Mixpanel sharedInstance] track:@"Settings"];

    [self setTitle:NSLocalizedString(@"SettingsTitle", @"View titles")];

    [[self tableView] registerClass:[UITableViewCell class] forCellReuseIdentifier:kSettingsCellIdentifier];
    [[self tableView] registerClass:[UITableViewCell class] forCellReuseIdentifier:kSettingsSwitchCellIdentifier];

    UIBarButtonItem *closeBarButtonItem = [[UIBarButtonItem alloc] initWithTitle:NSLocalizedString(@"CloseButton", @"Button titles") style:UIBarButtonItemStylePlain target:self action:@selector(close)];
    [[self navigationItem] setLeftBarButtonItem:closeBarButtonItem];

    NSString *applicationName = [[NSBundle mainBundle] objectForInfoDictionaryKey:@"CFBundleDisplayName"];
    NSString *versionNumber = [[NSBundle mainBundle] objectForInfoDictionaryKey:@"CFBundleShortVersionString"];
    NSString *buildNumber = [[NSBundle mainBundle] objectForInfoDictionaryKey:@"CFBundleVersion"];

    UILabel *footerLabel = [[UILabel alloc] initWithFrame:CGRectMake(0, 0, self.tableView.frame.size.width, 40)];
    [footerLabel setTextAlignment:NSTextAlignmentCenter];
    [footerLabel setFont:[UIFont preferredFontForTextStyle:UIFontTextStyleFootnote]];
    [footerLabel setTextColor:[[CSAppearanceManager defaultManager] darkTextColor]];
    [footerLabel setText:[[NSString alloc] initWithFormat:@"%@ %@ (%@)", applicationName, versionNumber, buildNumber]];
    [[self tableView] setTableFooterView:footerLabel];

    [[NSNotificationCenter defaultCenter] addObserver:self selector:@selector(updateSwitch) name:CSFailedToRegisterForRemoteNotificationsNotification object:nil];
    [[NSNotificationCenter defaultCenter] addObserver:self selector:@selector(preferredContentSizeChanged:) name:UIContentSizeCategoryDidChangeNotification object:nil];
}

- (void)dealloc {
    [[NSNotificationCenter defaultCenter] removeObserver:self name:CSFailedToRegisterForRemoteNotificationsNotification object:nil];
    [[NSNotificationCenter defaultCenter] removeObserver:self name:UIContentSizeCategoryDidChangeNotification object:nil];
}

@end
