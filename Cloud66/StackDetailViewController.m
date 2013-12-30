//
//  StackDetailViewController.m
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
#import <FormatterKit/TTTTimeIntervalFormatter.h>
#import "CSNotificationView+MainQueue.h"
#import "GRAlertView.h"
#import "SVWebViewController.h"
#import "Stack.h"
#import "StatusView.h"
#import "StackDetailTableViewCell.h"
#import "CSAppearanceManager.h"
#import "StackDetailViewController.h"

#pragma mark StackDetailViewController (Private)

@interface StackDetailViewController () <NSFetchedResultsControllerDelegate>

@property (strong, nonatomic) NSMutableArray *sections;
@property (strong, nonatomic, readonly) NSFetchedResultsController *fetchedResultsController;
@property (strong, nonatomic) NSDate *lastRefresh;
@property (strong, nonatomic) NSTimer *refreshUpdateTimer;

@end

#pragma mark - StackDetailViewController

@implementation StackDetailViewController

#pragma mark - Getters/Setters

@synthesize sections;
@synthesize fetchedResultsController;
@synthesize lastRefresh;
@synthesize refreshUpdateTimer;

- (NSFetchedResultsController *)fetchedResultsController {
    if (!fetchedResultsController) {
        NSFetchRequest *fetchRequest = [[NSFetchRequest alloc] initWithEntityName:@"Stack"];
        [fetchRequest setPredicate:[NSPredicate predicateWithFormat:@"uid = %@", [[self stack] uid]]];
        [fetchRequest setSortDescriptors:@[ [NSSortDescriptor sortDescriptorWithKey:@"name" ascending:YES] ]];

        NSFetchedResultsController *aFetchedResultsController = [[NSFetchedResultsController alloc] initWithFetchRequest:fetchRequest managedObjectContext:[CSAppDelegate managedObjectContext] sectionNameKeyPath:nil cacheName:nil];
        [aFetchedResultsController setDelegate:self];

        NSError *error;
        if ([aFetchedResultsController performFetch:&error] && !error) {
            fetchedResultsController = aFetchedResultsController;
        } else {
            [[Mixpanel sharedInstance] trackErrorInClass:[[StackDetailViewController class] description] function:__PRETTY_FUNCTION__ line:__LINE__ type:[NSString stringWithFormat:@"Fetch-%d", [error code]]];

            return nil;
        }
    }
    
    return fetchedResultsController;
}

#pragma mark - Button actions

- (void)refresh {
    NSAttributedString *attributedTitle = [[NSAttributedString alloc] initWithString:NSLocalizedString(@"RefreshingData", @"Refresh messages") attributes:@{ NSForegroundColorAttributeName : [[CSAppearanceManager defaultManager] lightTextColor] }];
    [[[self stackTableViewController] refreshControl] setAttributedTitle:attributedTitle];
    [[[self stackTableViewController] refreshControl] beginRefreshing];

    [[self stack] updateWithSuccess:^(BOOL hasNewData){
        [[self refreshUpdateTimer] invalidate];
        [self setLastRefresh:[NSDate date]];
        NSTimer *timer = [NSTimer timerWithTimeInterval:60 target:self selector:@selector(updateRefreshDate) userInfo:nil repeats:YES];
        [[NSRunLoop mainRunLoop] addTimer:timer forMode:NSDefaultRunLoopMode];
        [self setRefreshUpdateTimer:timer];

        [self updateRefreshDate];
        [[[self stackTableViewController] refreshControl] endRefreshing];
    } failure:^(NSError *error) {
        NSAttributedString *attributedTitle = [[NSAttributedString alloc] initWithString:NSLocalizedString(@"FailedToRefresh", @"Refresh messages") attributes:@{ NSForegroundColorAttributeName : [[CSAppearanceManager defaultManager] lightTextColor] }];
        [[[self stackTableViewController] refreshControl] setAttributedTitle:attributedTitle];
        [[[self stackTableViewController] refreshControl] endRefreshing];

        [CSNotificationView showInMainQueueAndInViewController:self style:CSNotificationViewStyleError message:NSLocalizedString(@"FailedToRefresh", @"Refresh messages")];
    }];
}

- (void)toggleMaintenance {
    BOOL maintenanceMode = ![[[self stack] maintenanceMode] boolValue];

    [[Mixpanel sharedInstance] track:@"Maintenance" properties:@{ @"Enabled" : [NSNumber numberWithBool:maintenanceMode] }];

    [[self stack] setMaintenanceModeEnabled:maintenanceMode success:^{
        [Appirater userDidSignificantEvent:YES];

        [CSNotificationView showInMainQueueAndInViewController:self style:CSNotificationViewStyleSuccess message:(maintenanceMode) ? NSLocalizedString(@"StackMaintenanceNowOn", @"Notification messages") : NSLocalizedString(@"StackMaintenanceNowOff", @"Notification messages")];
    } failure:^(NSError *error) {
        [CSNotificationView showInMainQueueAndInViewController:self style:CSNotificationViewStyleError message:NSLocalizedString(@"StackMaintenanceFailed", @"Notification messages")];
    }];
}

- (void)redeploy {
    [[Mixpanel sharedInstance] track:@"Redeploy"];

    [[self stack] redeployWithSuccess:^{
        [Appirater userDidSignificantEvent:YES];

        [CSNotificationView showInMainQueueAndInViewController:self style:CSNotificationViewStyleSuccess message:NSLocalizedString(@"StackQueuedForDeployment", @"Notification messages")];
    } failure:^(NSError *error) {
        [CSNotificationView showInMainQueueAndInViewController:self style:CSNotificationViewStyleError message:NSLocalizedString(@"StackFailedToQueue", @"Notification messages")];
    }];
}

- (void)openGit {
    [[Mixpanel sharedInstance] track:@"Open Git"];

    [Appirater userDidSignificantEvent:YES];

    NSString *url = [[[self stack] git] stringByReplacingOccurrencesOfString:@"git@github.com:" withString:@"https://github.com/"];
    url = [url stringByReplacingOccurrencesOfString:@"git://github.com/" withString:@"https://github.com/"];
    url = [url stringByReplacingOccurrencesOfString:@".git" withString:[NSString stringWithFormat:@"/commits/%@", [[self stack] gitBranch]]];

    SVWebViewController *webViewController = [[SVWebViewController alloc] initWithURL:[NSURL URLWithString:url]];
    [[self navigationController] pushViewController:webViewController animated:YES];
}

- (void)copyUID:(id)sender {
    [[Mixpanel sharedInstance] track:@"Copy UID"];

    [Appirater userDidSignificantEvent:YES];

    [[UIPasteboard generalPasteboard] setString:[[self stack] uid]];
}

#pragma mark - Timer

- (void)updateRefreshDate {
    if (abs([[self lastRefresh] timeIntervalSinceNow]) > (60 * 60 * 6)) {
        [[self refreshUpdateTimer] invalidate];
        [self setRefreshUpdateTimer:nil];
        [[[self stackTableViewController] refreshControl] setAttributedTitle:nil];

        return;
    }

    TTTTimeIntervalFormatter *timeIntervalFormatter = [TTTTimeIntervalFormatter new];
    [timeIntervalFormatter setPresentTimeIntervalMargin:60];

    NSString *interval = [timeIntervalFormatter stringForTimeInterval:[[self lastRefresh] timeIntervalSinceNow]];
    NSAttributedString *refreshSentence = [[NSAttributedString alloc] initWithString:[NSString stringWithFormat:NSLocalizedString(@"LastUpdatedOn", @"Refresh messages"), interval] attributes:@{ NSForegroundColorAttributeName : [[CSAppearanceManager defaultManager] lightTextColor] }];
    [[[self stackTableViewController] refreshControl] setAttributedTitle:refreshSentence];
}

- (void)removeUpdateTimer:(NSNotification *)notification {
    if ([self refreshUpdateTimer]) {
        [[self refreshUpdateTimer] invalidate];
        [self setRefreshUpdateTimer:nil];
        [[[self stackTableViewController] refreshControl] setAttributedTitle:[[NSAttributedString alloc] initWithString:@" "]];
    }
}

#pragma mark - Table creation

- (void)reloadData {
    [[[self stackTableViewController] tableView] setUserInteractionEnabled:NO];

    [sections removeAllObjects];

    NSMutableDictionary *info = [NSMutableDictionary dictionaryWithDictionary:@{
                                    @"title" : NSLocalizedString(@"InfoTitle", @"Stacks"),
                                    @"rows" : @[
                                            @{
                                                @"title" : NSLocalizedString(@"StackName", @"Stacks"),
                                                @"value" : [[self stack] name],
                                                @"type" : @"label"
                                                },
                                            @{
                                                @"title" : NSLocalizedString(@"StackCreatedAt", @"Stacks"),
                                                @"value" : [[self stack] createdAtString],
                                                @"type" : @"label"
                                                }
                                            ]
                                    }];

    [sections addObject:info];

    NSMutableDictionary *status = [NSMutableDictionary dictionaryWithDictionary:@{
                                      @"title" : NSLocalizedString(@"StatusTitle", @"Stacks"),
                                      @"rows" : @[
                                              @{
                                                  @"title" : NSLocalizedString(@"StackLastActivity", @"Stacks"),
                                                  @"value" : [[self stack] lastActivityString],
                                                  @"type" : @"label"
                                                  },
                                              @{
                                                  @"title" : NSLocalizedString(@"StackStatus", @"Stacks"),
                                                  @"value" : [[self stack] statusString],
                                                  @"type" : @"label"
                                                  }
                                              ]
                                      }];

    [sections addObject:status];

    NSMutableDictionary *settings = [NSMutableDictionary dictionaryWithDictionary:@{
                                        @"title" : NSLocalizedString(@"SettingsTitle", @"Stacks"),
                                        @"rows" : @[
                                                @{
                                                    @"title" : NSLocalizedString(@"StackEnvironment", @"Stacks"),
                                                    @"value" : [[[self stack] environment] capitalizedString],
                                                    @"type" : @"label"
                                                    },
                                                @{
                                                    @"title" : NSLocalizedString(@"StackGitBranch", @"Stacks"),
                                                    @"value" : [[self stack] gitBranch],
                                                    @"type" : ([[[self stack] git] rangeOfString:@"github"].location == NSNotFound) ? @"label" : @"detail",
                                                    @"selector" : @"openGit"
                                                    },
                                                @{
                                                    @"title" : NSLocalizedString(@"StackLanguage", @"Stacks"),
                                                    @"value" : [[[self stack] language] capitalizedString],
                                                    @"type" : @"label"
                                                    },
                                                @{
                                                    @"title" : NSLocalizedString(@"StackFramework", @"Stacks"),
                                                    @"value" : [[[self stack] framework] capitalizedString],
                                                    @"type" : @"label"
                                                    }
                                                ]
                                        }];

    [sections addObject:settings];
    
    NSMutableDictionary *servers = [NSMutableDictionary dictionaryWithDictionary:@{
                                       @"title" : NSLocalizedString(@"ServersTitle", @"Stacks"),
                                       @"rows" : @[
                                               @{
                                                   @"title" : NSLocalizedString(@"StackCloud", @"Stacks"),
                                                   @"value" : [[self stack] cloud],
                                                   @"type" : @"cloud"
                                                   }
                                               ]
                                       }];

    [sections addObject:servers];
    
    NSString *maitenance = [[[self stack] maintenanceMode] boolValue] ? NSLocalizedString(@"StackMaintenanceOff", @"Stacks") : NSLocalizedString(@"StackMaintenanceOn", @"Stacks");
    NSDictionary *actions = [NSMutableDictionary dictionaryWithDictionary:@{
                              @"rows" : @[
                                      @{
                                          @"title" : maitenance,
                                          @"type" : @"maintenance",
                                          @"selector" : @"toggleMaintenance"
                                          }
                                      ]
                              }];
    
    [sections addObject:actions];
    
    NSDictionary *destructiveActions = [NSMutableDictionary dictionaryWithDictionary:@{
                                         @"rows" : @[
                                                 @{
                                                     @"title" : NSLocalizedString(@"StackRedeploy", @"Stacks"),
                                                     @"type" : @"destructive",
                                                     @"selector" : @"redeploy"
                                                     }
                                                 ]
                                         }];
    [sections addObject:destructiveActions];

    [[self healthView] setBackgroundColor:[[self stack] healthColor]];

    [[[self stackTableViewController] tableView] reloadData];

    [[[self stackTableViewController] tableView] setUserInteractionEnabled:YES];
}

#pragma mark - Table view data source

- (NSInteger)numberOfSectionsInTableView:(UITableView *)tableView {
    return [[self sections] count];
}

- (NSInteger)tableView:(UITableView *)tableView numberOfRowsInSection:(NSInteger)section {
    return [[[[self sections] objectAtIndex:section] objectForKey:@"rows"] count];
}

- (CGFloat)tableView:(UITableView *)tableView heightForRowAtIndexPath:(NSIndexPath *)indexPath {
    static UILabel *stackHeightLabel;
    if (!stackHeightLabel) {
        stackHeightLabel = [[UILabel alloc] initWithFrame:CGRectMake(0, 0, FLT_MAX, FLT_MAX)];
        [stackHeightLabel setText:@"TEST"];
    }

    [stackHeightLabel setFont:[UIFont preferredFontForTextStyle:UIFontTextStyleHeadline]];
    [stackHeightLabel sizeToFit];

    return (int)(stackHeightLabel.frame.size.height * 2);
}

- (NSString *)tableView:(UITableView *)tableView titleForHeaderInSection:(NSInteger)section {
    return [[[[self sections] objectAtIndex:section] objectForKey:@"title"] uppercaseString];
}

- (BOOL)tableView:(UITableView *)tableView shouldShowMenuForRowAtIndexPath:(NSIndexPath *)indexPath {
    if (indexPath.section == 0 && indexPath.row == 0) {
        return YES;
    }

    return NO;
}

- (BOOL)tableView:(UITableView *)tableView canPerformAction:(SEL)action forRowAtIndexPath:(NSIndexPath *)indexPath withSender:(id)sender {
    if (action == @selector(copyUID:)) {
        return YES;
    }

    return NO;
}

- (void)tableView:(UITableView *)tableView performAction:(SEL)action forRowAtIndexPath:(NSIndexPath *)indexPath withSender:(id)sender {
    SuppressPerformSelectorLeakWarning([self performSelector:action];);
}

- (UITableViewCell *)tableView:(UITableView *)tableView cellForRowAtIndexPath:(NSIndexPath *)indexPath {
    NSDictionary *row = [self sections][indexPath.section][@"rows"][indexPath.row];

    StackDetailTableViewCell *cell;
    if ([row[@"type"] isEqualToString:@"label"]) {
        static NSString *kStackLabelCellIdentifier = @"kStackLabelCellIdentifier";
        cell = [tableView dequeueReusableCellWithIdentifier:kStackLabelCellIdentifier];
        if (cell == nil) {
            cell = [[StackDetailTableViewCell alloc] initWithStyle:UITableViewCellStyleValue1 reuseIdentifier:kStackLabelCellIdentifier];
            [cell setSelectionStyle:UITableViewCellSelectionStyleNone];
            [[cell textLabel] setTextColor:[[CSAppearanceManager defaultManager] darkTextColor]];
            [[cell detailTextLabel] setTextColor:[[CSAppearanceManager defaultManager] lightTextColor]];
            [cell setDelegate:self];
        }

        [[cell textLabel] setFont:[UIFont preferredFontForTextStyle:UIFontTextStyleHeadline]];
        [[cell detailTextLabel] setFont:[UIFont preferredFontForTextStyle:UIFontTextStyleSubheadline]];
    } else if ([row[@"type"] isEqualToString:@"detail"]) {
        static NSString *kStackDetailCellIdentifier = @"kStackDetailCellIdentifier";
        cell = [tableView dequeueReusableCellWithIdentifier:kStackDetailCellIdentifier];
        if (cell == nil) {
            cell = [[StackDetailTableViewCell alloc] initWithStyle:UITableViewCellStyleValue1 reuseIdentifier:kStackDetailCellIdentifier];
            [cell setSelectionStyle:UITableViewCellSelectionStyleDefault];
            [[cell textLabel] setTextColor:[[CSAppearanceManager defaultManager] darkTextColor]];
            [[cell detailTextLabel] setTextColor:[[CSAppearanceManager defaultManager] lightTextColor]];
            [cell setAccessoryType:UITableViewCellAccessoryDisclosureIndicator];
        }

        [[cell textLabel] setFont:[UIFont preferredFontForTextStyle:UIFontTextStyleHeadline]];
        [[cell detailTextLabel] setFont:[UIFont preferredFontForTextStyle:UIFontTextStyleSubheadline]];
    } else if ([row[@"type"] isEqualToString:@"cloud"]) {
        static NSString *kStackLabelCellIdentifier = @"kStackCloudCellIdentifier";
        cell = [tableView dequeueReusableCellWithIdentifier:kStackLabelCellIdentifier];
        if (cell == nil) {
            cell = [[StackDetailTableViewCell alloc] initWithStyle:UITableViewCellStyleValue1 reuseIdentifier:kStackLabelCellIdentifier];
            [cell setSelectionStyle:UITableViewCellSelectionStyleNone];
            [[cell textLabel] setTextColor:[[CSAppearanceManager defaultManager] darkTextColor]];
            [[cell textLabel] setFont:[UIFont preferredFontForTextStyle:UIFontTextStyleHeadline]];
            [[cell detailTextLabel] setTextColor:[[CSAppearanceManager defaultManager] lightTextColor]];
            [[cell detailTextLabel] setFont:[UIFont preferredFontForTextStyle:UIFontTextStyleSubheadline]];

            [cell setShowStatusView:YES];
        }

        [[cell textLabel] setFont:[UIFont preferredFontForTextStyle:UIFontTextStyleHeadline]];
        [[cell detailTextLabel] setFont:[UIFont preferredFontForTextStyle:UIFontTextStyleSubheadline]];

        [[cell statusView] setStack:[self stack]];
        [[cell statusView] refresh];
    } else if ([row[@"type"] isEqualToString:@"destructive"]) {
        static NSString *kStackDestructiveCellIdentifier = @"kStackDestructiveCellIdentifier";
        cell = [tableView dequeueReusableCellWithIdentifier:kStackDestructiveCellIdentifier];
        if (cell == nil) {
            cell = [[StackDetailTableViewCell alloc] initWithStyle:UITableViewCellStyleDefault reuseIdentifier:kStackDestructiveCellIdentifier];
            [cell setBackgroundColor:[[CSAppearanceManager defaultManager] redColor]];
            [[cell textLabel] setTextColor:[UIColor whiteColor]];
            [[cell textLabel] setTextAlignment:NSTextAlignmentCenter];
        }

        [[cell textLabel] setFont:[UIFont preferredFontForTextStyle:UIFontTextStyleHeadline]];
    } else if ([row[@"type"] isEqualToString:@"maintenance"]) {
        static NSString *kStackMaintenanceCellIdentifier = @"kStackMaintenanceCellIdentifier";
        cell = [tableView dequeueReusableCellWithIdentifier:kStackMaintenanceCellIdentifier];
        if (cell == nil) {
            cell = [[StackDetailTableViewCell alloc] initWithStyle:UITableViewCellStyleDefault reuseIdentifier:kStackMaintenanceCellIdentifier];
            [cell setBackgroundColor:[[CSAppearanceManager defaultManager] tintColor]];
            [[cell textLabel] setTextColor:[UIColor whiteColor]];
            [[cell textLabel] setTextAlignment:NSTextAlignmentCenter];
        }

        [[cell textLabel] setFont:[UIFont preferredFontForTextStyle:UIFontTextStyleHeadline]];
    }

    [[cell textLabel] setText:[row objectForKey:@"title"]];
    [[cell detailTextLabel] setText:[row objectForKey:@"value"]];

    return cell;
}

#pragma mark - Table view delegate

- (void)tableView:(UITableView *)tableView didSelectRowAtIndexPath:(NSIndexPath *)indexPath {
    [tableView deselectRowAtIndexPath:indexPath animated:YES];

    NSDictionary *row = [self sections][indexPath.section][@"rows"][indexPath.row];
    if ([row[@"type"] isEqualToString:@"detail"]) {
        SuppressPerformSelectorLeakWarning(
           [self performSelector:NSSelectorFromString(row[@"selector"])];
       );
    } else if ([row[@"type"] isEqualToString:@"destructive"]) {
        GRAlertView *alertView = [[GRAlertView alloc] initWithTitle:NSLocalizedString(@"RedeployAlertTitle", @"Alerts") message:NSLocalizedString(@"RedeployAlertMessage", @"Alerts")];
        [alertView setCancelButtonWithTitle:NSLocalizedString(@"CancelAlertButton", @"Alerts") block:nil];
        [alertView setOtherButtonWithTitle:NSLocalizedString(@"ConfirmAlertButton", @"Alerts") block:^{
            SuppressPerformSelectorLeakWarning(
               [self performSelector:NSSelectorFromString(row[@"selector"])];
            );
        }];
        [alertView show];
    } else if ([row[@"type"] isEqualToString:@"maintenance"]) {
        NSString *maintenance = [[[self stack] maintenanceMode] boolValue] ? NSLocalizedString(@"MaintenanceOffAlertMessage", @"Alerts") : NSLocalizedString(@"MaintenanceOnAlertMessage", @"Alerts");
        GRAlertView *alertView = [[GRAlertView alloc] initWithTitle:NSLocalizedString(@"MaintenanceAlertTitle", @"Alerts") message:maintenance];
        [alertView setCancelButtonWithTitle:NSLocalizedString(@"CancelAlertButton", @"Alerts") block:nil];
        [alertView setOtherButtonWithTitle:NSLocalizedString(@"ConfirmAlertButton", @"Alerts") block:^{
            SuppressPerformSelectorLeakWarning(
               [self performSelector:NSSelectorFromString(row[@"selector"])];
           );
        }];
        [alertView show];
    }
}

#pragma mark - Fetched results controller delegate

- (void)controllerDidChangeContent:(NSFetchedResultsController *)controller {
    @try {
        [self setStack:[[self fetchedResultsController] objectAtIndexPath:[NSIndexPath indexPathForRow:0 inSection:0]]];

        [self reloadData];
    }
    @catch (NSException *exception) {
        [[self navigationController] popToRootViewControllerAnimated:YES];
    }
}

#pragma mark - Font size delegate

- (void)preferredContentSizeChanged:(NSNotification *)notification {
    [[[self stackTableViewController] tableView] reloadData];
}

#pragma mark - View lifecycle

- (void)viewDidLoad {
    [super viewDidLoad];

    [[Mixpanel sharedInstance] track:@"Details"];

    [self setTitle:NSLocalizedString(@"StackDetailTitle", @"View titles")];

    [self setEdgesForExtendedLayout:UIRectEdgeLeft | UIRectEdgeBottom | UIRectEdgeRight];

    [self fetchedResultsController];
    sections = [NSMutableArray array];
    [self reloadData];

    UIRefreshControl *refreshControl = [UIRefreshControl new];
    [refreshControl setTintColor:[[CSAppearanceManager defaultManager] tintColor]
     ];
    [refreshControl addTarget:self action:@selector(refresh) forControlEvents:UIControlEventValueChanged];
    [refreshControl setAttributedTitle:[[NSAttributedString alloc] initWithString:@" "]];
    [[self stackTableViewController] setRefreshControl:refreshControl];

    [[[self stackTableViewController] tableView] setBackgroundColor:[[CSAppearanceManager defaultManager] backgroundColor]
     ];

    [self addChildViewController:[self stackTableViewController]];
    [[self view] insertSubview:[[self stackTableViewController] tableView] belowSubview:[self healthView]];
    [[[self stackTableViewController] tableView] setFrame:self.view.bounds];

    UIMenuItem *uidMenuItem = [[UIMenuItem alloc] initWithTitle:NSLocalizedString(@"CopyUIDMenuButton", @"Button titles") action:@selector(copyUID:)];
    [[UIMenuController sharedMenuController] setMenuItems:@[ uidMenuItem ]];
    [[UIMenuController sharedMenuController] update];

    [[NSNotificationCenter defaultCenter] addObserver:self selector:@selector(removeUpdateTimer:) name:UIApplicationDidEnterBackgroundNotification object:nil];
    [[NSNotificationCenter defaultCenter] addObserver:self selector:@selector(preferredContentSizeChanged:) name:UIContentSizeCategoryDidChangeNotification object:nil];
}

- (void)dealloc {
    [[[self stackTableViewController] tableView] removeFromSuperview];
    [[self stackTableViewController] removeFromParentViewController];

    [[NSNotificationCenter defaultCenter] removeObserver:self name:UIApplicationDidEnterBackgroundNotification object:nil];
    [[NSNotificationCenter defaultCenter] removeObserver:self name:UIContentSizeCategoryDidChangeNotification object:nil];
}

@end
