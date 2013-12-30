//
//  StacksViewController.m
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

#import <FormatterKit/TTTTimeIntervalFormatter.h>
#import "CSNotificationView+MainQueue.h"
#import "CSAppearanceManager.h"
#import "CSAPISessionManager.h"
#import "Stack.h"
#import "Status.h"
#import "StackTableViewCell.h"
#import "SVWebViewController.h"
#import "SettingsViewController.h"
#import "StackDetailViewController.h"
#import "StacksViewController.h"

static NSString *kStackCellIdentifier = @"kStackCellIdentifier";

#pragma mark StacksViewController (Private)

@interface StacksViewController () <NSFetchedResultsControllerDelegate, UISearchDisplayDelegate>

@property (strong, nonatomic, readonly) NSFetchedResultsController *fetchedResultsController;
@property (strong, nonatomic) NSDate *lastRefresh;
@property (strong, nonatomic) NSTimer *refreshUpdateTimer;
@property (strong, nonatomic) UIBarButtonItem *statusBarButtonItem;
@property (strong, nonatomic) UIBarButtonItem *statusRefreshBarButtonItem;

@end

#pragma mark - StacksViewController

@implementation StacksViewController

#pragma mark - Getters/Setters

@synthesize fetchedResultsController;
@synthesize lastRefresh;
@synthesize refreshUpdateTimer;
@synthesize statusBarButtonItem;
@synthesize statusRefreshBarButtonItem;

- (NSFetchedResultsController *)fetchedResultsController {
    if (!fetchedResultsController) {
        NSFetchRequest *fetchRequest = [[NSFetchRequest alloc] initWithEntityName:@"Stack"];

        NSMutableArray *sortDescriptors = [NSMutableArray array];

        NSString *section;
        if ([[self searchDisplayController] isActive]) {
            NSPredicate *predicate = [NSPredicate predicateWithFormat:@"name CONTAINS[cd] %@", [[[self searchDisplayController] searchBar] text]];
            [fetchRequest setPredicate:predicate];
        } else {
            section = @"section";
            [sortDescriptors addObject:[NSSortDescriptor sortDescriptorWithKey:section ascending:YES]];
        }

        [sortDescriptors addObject:[NSSortDescriptor sortDescriptorWithKey:@"name" ascending:YES]];

        [fetchRequest setSortDescriptors:sortDescriptors];

        NSFetchedResultsController *aFetchedResultsController = [[NSFetchedResultsController alloc] initWithFetchRequest:fetchRequest managedObjectContext:[CSAppDelegate managedObjectContext] sectionNameKeyPath:section cacheName:nil];
        [aFetchedResultsController setDelegate:self];

        NSError *error;
        if ([aFetchedResultsController performFetch:&error] && !error) {
            fetchedResultsController = aFetchedResultsController;
        } else {
            [[Mixpanel sharedInstance] trackErrorInClass:[[StacksViewController class] description] function:__PRETTY_FUNCTION__ line:__LINE__ type:[NSString stringWithFormat:@"Fetch-%d", [error code]]];

            return nil;
        }
    }

    return fetchedResultsController;
}

- (UIBarButtonItem *)statusBarButtonItem {
    if (!statusBarButtonItem) {
        statusBarButtonItem = [[UIBarButtonItem alloc] initWithImage:[UIImage imageNamed:@"StatusIcon"] style:UIBarButtonItemStylePlain target:self action:@selector(refreshStatus)];
        [statusBarButtonItem setTintColor:[[CSAppearanceManager defaultManager] lightTextColor]];
    }

    return statusBarButtonItem;
}

- (UIBarButtonItem *)statusBarButtonItemForStatus:(CSStatus)status {
    [[self statusBarButtonItem] setTintColor:[Status colorForStatus:status]];
    if (status == CSStatusUnkknown) {
        [[self statusBarButtonItem] setAction:@selector(refreshStatus)];
    } else {
        [[self statusBarButtonItem] setAction:@selector(showStatus)];
    }

    return [self statusBarButtonItem];
}

- (UIBarButtonItem *)statusRefreshBarButtonItem {
    if (!statusRefreshBarButtonItem) {
        UIActivityIndicatorView *activityIndicatorView = [[UIActivityIndicatorView alloc] initWithActivityIndicatorStyle:UIActivityIndicatorViewStyleGray];
        [activityIndicatorView startAnimating];

        statusRefreshBarButtonItem = [[UIBarButtonItem alloc] initWithCustomView:activityIndicatorView];
        [statusRefreshBarButtonItem setTintColor:[[CSAppearanceManager defaultManager] lightTextColor]];
    }

    return statusRefreshBarButtonItem;
}

#pragma mark - Search delegate

- (void)searchDisplayController:(UISearchDisplayController *)controller willShowSearchResultsTableView:(UITableView *)tableView {
    [[Mixpanel sharedInstance] track:@"Search"];
}

- (BOOL)searchDisplayController:(UISearchDisplayController *)controller shouldReloadTableForSearchString:(NSString *)searchString {
    fetchedResultsController = nil;

    return YES;
}

- (void)searchDisplayControllerWillEndSearch:(UISearchDisplayController *)controller {
    fetchedResultsController = nil;
}

#pragma mark - Buttons actions

- (void)refresh {
    NSAttributedString *attributedTitle = [[NSAttributedString alloc] initWithString:NSLocalizedString(@"RefreshingData", @"Refresh messages") attributes:@{ NSForegroundColorAttributeName : [[CSAppearanceManager defaultManager] lightTextColor] }];
    [[[self stacksTableViewController] refreshControl] setAttributedTitle:attributedTitle];
    [[[self stacksTableViewController] refreshControl] beginRefreshing];

    [Stack syncWithSuccess:^(BOOL hasNewData){
        [[self refreshUpdateTimer] invalidate];
        [self setLastRefresh:[NSDate date]];
        NSTimer *timer = [NSTimer timerWithTimeInterval:60 target:self selector:@selector(updateRefreshDate) userInfo:nil repeats:YES];
        [[NSRunLoop mainRunLoop] addTimer:timer forMode:NSDefaultRunLoopMode];
        [self setRefreshUpdateTimer:timer];

        [self updateRefreshDate];
        [[[self stacksTableViewController] refreshControl] endRefreshing];
    } failure:^(NSError *error) {
        NSAttributedString *attributedTitle = [[NSAttributedString alloc] initWithString:NSLocalizedString(@"FailedToRefresh", @"Refresh messages") attributes:@{ NSForegroundColorAttributeName : [[CSAppearanceManager defaultManager] lightTextColor] }];
        [[[self stacksTableViewController] refreshControl] setAttributedTitle:attributedTitle];
        [[[self stacksTableViewController] refreshControl] endRefreshing];

        [CSNotificationView showInMainQueueAndInViewController:self style:CSNotificationViewStyleError message:NSLocalizedString(@"FailedToRefresh", @"Refresh messages")];
    }];
}

- (void)refreshStatus {
    [[self navigationItem] setRightBarButtonItem:[self statusRefreshBarButtonItem]];
    [Status statusWithSuccess:^(CSStatus status) {
        dispatch_async(dispatch_get_main_queue(), ^{
            [[self navigationItem] setRightBarButtonItem:[self statusBarButtonItemForStatus:status] animated:YES];
        });
    } failure:^(NSError *error) {
        dispatch_async(dispatch_get_main_queue(), ^{
            [[self navigationItem] setRightBarButtonItem:[self statusBarButtonItemForStatus:CSStatusUnkknown] animated:YES];

            [CSNotificationView showInViewController:self style:CSNotificationViewStyleError message:NSLocalizedString(@"StatusFailedRefresh", @"Notification messages")];
        });
    }];
}

- (void)showSettings {
    SettingsViewController *settingsViewController = [[SettingsViewController alloc] initWithNibName:@"SettingsViewController" bundle:nil];
    UINavigationController *settingsNavigationController = [[UINavigationController alloc] initWithRootViewController:settingsViewController];
    [self presentViewController:settingsNavigationController animated:YES completion:nil];
}

- (void)showStatus {
    [[Mixpanel sharedInstance] track:@"Status" properties:@{ @"Screen" : @"Stacks" }];

    SVWebViewController *webViewController = [[SVWebViewController alloc] initWithURL:[NSURL URLWithString:CS_STATUS_ADDRESS]];
    UINavigationController *statusNavigationController = [[UINavigationController alloc] initWithRootViewController:webViewController];
    [self presentViewController:statusNavigationController animated:YES completion:nil];
}

#pragma mark - Timer

- (void)updateRefreshDate {
    if (abs([[self lastRefresh] timeIntervalSinceNow]) > (60 * 60 * 6)) {
        [[self refreshUpdateTimer] invalidate];
        [self setRefreshUpdateTimer:nil];
        [[[self stacksTableViewController] refreshControl] setAttributedTitle:[[NSAttributedString alloc] initWithString:@" "]];

        return;
    }

    TTTTimeIntervalFormatter *timeIntervalFormatter = [TTTTimeIntervalFormatter new];
    [timeIntervalFormatter setPresentTimeIntervalMargin:60];

    NSString *interval = [timeIntervalFormatter stringForTimeInterval:[[self lastRefresh] timeIntervalSinceNow]];
    NSAttributedString *refreshSentence = [[NSAttributedString alloc] initWithString:[NSString stringWithFormat:NSLocalizedString(@"LastUpdatedOn", @"Refresh messages"), interval] attributes:@{ NSForegroundColorAttributeName : [[CSAppearanceManager defaultManager] lightTextColor] }];
    [[[self stacksTableViewController] refreshControl] setAttributedTitle:refreshSentence];
}

- (void)removeUpdateTimer:(NSNotification *)notification {
    [[self refreshUpdateTimer] invalidate];
    [self setRefreshUpdateTimer:nil];
    [[[self stacksTableViewController] refreshControl] setAttributedTitle:[[NSAttributedString alloc] initWithString:@" "]];
}

#pragma mark - Table view data source

- (NSInteger)numberOfSectionsInTableView:(UITableView *)tableView {
    return [[[self fetchedResultsController] sections] count];
}

- (CGFloat)tableView:(UITableView *)tableView heightForRowAtIndexPath:(NSIndexPath *)indexPath {
    static UILabel *stackHeightLabel;
    if (!stackHeightLabel) {
        stackHeightLabel = [[UILabel alloc] initWithFrame:CGRectMake(0, 0, FLT_MAX, FLT_MAX)];
        [stackHeightLabel setText:@"TEST"];
    }

    [stackHeightLabel setFont:[UIFont preferredFontForTextStyle:UIFontTextStyleHeadline]];
    [stackHeightLabel sizeToFit];

    return (int)(stackHeightLabel.frame.size.height * 3.7);
}

- (NSString *)tableView:(UITableView *)tableView titleForHeaderInSection:(NSInteger)section {
    if ([[self searchDisplayController] isActive]) {
        return nil;
    }

    id <NSFetchedResultsSectionInfo> sectionInfo = [[[self fetchedResultsController] sections] objectAtIndex:section];

    return NSLocalizedString([sectionInfo name], @"Section");
}

- (NSInteger)tableView:(UITableView *)tableView numberOfRowsInSection:(NSInteger)section {
    if ([[[self fetchedResultsController] sections] count] > 0) {
        id <NSFetchedResultsSectionInfo> sectionInfo = [[[self fetchedResultsController] sections] objectAtIndex:section];

        return [sectionInfo numberOfObjects];
    }

    return 0;
}

- (CGFloat)tableView:(UITableView *)tableView heightForFooterInSection:(NSInteger)section {
    return 0.01f;
}

- (UITableViewCell *)tableView:(UITableView *)tableView cellForRowAtIndexPath:(NSIndexPath *)indexPath {
    StackTableViewCell *cell = [tableView dequeueReusableCellWithIdentifier:kStackCellIdentifier];

    Stack *stack = [[self fetchedResultsController] objectAtIndexPath:indexPath];
    [cell setStack:stack];
    [cell setContainingTableView:tableView];

    return cell;
}

#pragma mark - Table view delegate

- (void)tableView:(UITableView *)tableView didSelectRowAtIndexPath:(NSIndexPath *)indexPath {
    [tableView deselectRowAtIndexPath:indexPath animated:YES];

    Stack *stack = [[self fetchedResultsController] objectAtIndexPath:indexPath];

    StackDetailViewController *stackDetailViewController = [[StackDetailViewController alloc] initWithNibName:@"StackDetailViewController" bundle:nil];
    [stackDetailViewController setStack:stack];
    [[self navigationController] pushViewController:stackDetailViewController animated:YES];
}

#pragma mark - Fetched results controller delegate

- (void)controllerWillChangeContent:(NSFetchedResultsController *)controller {
    [[[self stacksTableViewController] tableView] beginUpdates];
}

- (void)controller:(NSFetchedResultsController *)controller didChangeSection:(id <NSFetchedResultsSectionInfo>)sectionInfo atIndex:(NSUInteger)sectionIndex forChangeType:(NSFetchedResultsChangeType)type {
    UITableView *tableView = [[self stacksTableViewController] tableView];

    switch(type) {
        case NSFetchedResultsChangeInsert:
            [tableView insertSections:[NSIndexSet indexSetWithIndex:sectionIndex] withRowAnimation:UITableViewRowAnimationFade];
            break;

        case NSFetchedResultsChangeDelete:
            [tableView deleteSections:[NSIndexSet indexSetWithIndex:sectionIndex] withRowAnimation:UITableViewRowAnimationFade];
            break;
    }
}

- (void)controller:(NSFetchedResultsController *)controller didChangeObject:(id)anObject atIndexPath:(NSIndexPath *)indexPath forChangeType:(NSFetchedResultsChangeType)type newIndexPath:(NSIndexPath *)newIndexPath {
    UITableView *tableView = [[self stacksTableViewController] tableView];

    switch(type) {
        case NSFetchedResultsChangeInsert: {
            [tableView insertRowsAtIndexPaths:[NSArray arrayWithObject:newIndexPath] withRowAnimation:UITableViewRowAnimationFade];
            break;
        }

        case NSFetchedResultsChangeDelete: {
            [tableView deleteRowsAtIndexPaths:[NSArray arrayWithObject:indexPath] withRowAnimation:UITableViewRowAnimationFade];
            break;
        }

        case NSFetchedResultsChangeUpdate: {
            Stack *stack = [[self fetchedResultsController] objectAtIndexPath:indexPath];
            [(StackTableViewCell *)[tableView cellForRowAtIndexPath:indexPath] setStack:stack];
            break;
        }

        case NSFetchedResultsChangeMove: {
            [tableView deleteRowsAtIndexPaths:[NSArray arrayWithObject:indexPath] withRowAnimation:UITableViewRowAnimationFade];
            [tableView insertRowsAtIndexPaths:[NSArray arrayWithObject:newIndexPath] withRowAnimation:UITableViewRowAnimationFade];
            break;
        }
    }
}

- (void)controllerDidChangeContent:(NSFetchedResultsController *)controller {
    [[[self stacksTableViewController] tableView] endUpdates];
}

#pragma mark - Authentication delegate

- (void)userDidLogout:(NSNotification *)notification {
    [self removeUpdateTimer:notification];

    fetchedResultsController = nil;

    [[[self stacksTableViewController] tableView] reloadData];
}

#pragma mark - Font size delegate

- (void)preferredContentSizeChanged:(NSNotification *)notification {
    [[[self stacksTableViewController] tableView] reloadData];
}

#pragma mark - View lifecycle

- (void)viewWillAppear:(BOOL)animated {
    [super viewWillAppear:animated];

    if ([[CSAPISessionManager sharedManager] isAuthenticated]) {
        [self refreshStatus];
    }
}

- (void)viewDidLoad {
    [super viewDidLoad];

    [[Mixpanel sharedInstance] track:@"Stacks"];

    [self setTitle:NSLocalizedString(@"StacksTitle", @"View titles")];

    UIBarButtonItem *settingsBarButtonItem = [[UIBarButtonItem alloc] initWithImage:[UIImage imageNamed:@"SettingsButton"] style:UIBarButtonItemStylePlain target:self action:@selector(showSettings)];
    [[self navigationItem] setLeftBarButtonItem:settingsBarButtonItem];

    [self refreshStatus];

    UINib *StackTableViewCellNib = [UINib nibWithNibName:@"StackTableViewCell" bundle:nil];
    [[[self stacksTableViewController] tableView] registerNib:StackTableViewCellNib forCellReuseIdentifier:kStackCellIdentifier];
    [[[self searchDisplayController] searchResultsTableView] registerNib:StackTableViewCellNib forCellReuseIdentifier:kStackCellIdentifier];
    [[[self searchDisplayController] searchResultsTableView] setRowHeight:[[[self stacksTableViewController] tableView] rowHeight]];

    [[[self stacksTableViewController] tableView] setBackgroundColor:[[CSAppearanceManager defaultManager] backgroundColor]];
    [[[self searchDisplayController] searchResultsTableView] setBackgroundColor:[[CSAppearanceManager defaultManager] backgroundColor]];

    UIRefreshControl *refreshControl = [UIRefreshControl new];
    [refreshControl setTintColor:[[CSAppearanceManager defaultManager] tintColor]
     ];
    [refreshControl addTarget:self action:@selector(refresh) forControlEvents:UIControlEventValueChanged];
    [refreshControl setAttributedTitle:[[NSAttributedString alloc] initWithString:@" "]];
    [[self stacksTableViewController] setRefreshControl:refreshControl];

    [self addChildViewController:[self stacksTableViewController]];
    [[self view] addSubview:[[self stacksTableViewController] tableView]];
    [[[self stacksTableViewController] tableView] setFrame:self.view.bounds];

    [self refresh];

    [[NSNotificationCenter defaultCenter] addObserver:self selector:@selector(userDidLogout:) name:CSUserDidLogoutNotification object:nil];
    [[NSNotificationCenter defaultCenter] addObserver:self selector:@selector(removeUpdateTimer:) name:UIApplicationDidEnterBackgroundNotification object:nil];
    [[NSNotificationCenter defaultCenter] addObserver:self selector:@selector(preferredContentSizeChanged:) name:UIContentSizeCategoryDidChangeNotification object:nil];
}

- (void)dealloc {
    [[NSNotificationCenter defaultCenter] removeObserver:self name:CSUserDidLogoutNotification object:nil];
    [[NSNotificationCenter defaultCenter] removeObserver:self name:UIApplicationDidEnterBackgroundNotification object:nil];
    [[NSNotificationCenter defaultCenter] removeObserver:self name:UIContentSizeCategoryDidChangeNotification object:nil];
}

@end
