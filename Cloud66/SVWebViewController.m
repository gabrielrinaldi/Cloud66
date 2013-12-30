//
//  SVWebViewController.m
//
//  Created by Sam Vermette on 08.11.10.
//  Copyright 2010 Sam Vermette. All rights reserved.
//
//  https://github.com/samvermette/SVWebViewController
//

#import "GRWebView.h"
#import "SVWebViewController.h"

#pragma mark SVWebViewController (Private)

@interface SVWebViewController ()

@property (strong, nonatomic, readonly) UIBarButtonItem *backBarButtonItem;
@property (strong, nonatomic, readonly) UIBarButtonItem *forwardBarButtonItem;
@property (strong, nonatomic, readonly) UIBarButtonItem *refreshBarButtonItem;
@property (strong, nonatomic, readonly) UIBarButtonItem *stopBarButtonItem;

@end

#pragma mark - SVWebViewController

@implementation SVWebViewController

#pragma mark - Getters/Setters

@synthesize backBarButtonItem;
@synthesize forwardBarButtonItem;
@synthesize refreshBarButtonItem;
@synthesize stopBarButtonItem;

- (void)setURL:(NSURL *)URL {
    [[self browserWebView] resetProgress];

    _URL = nil;
    _URL = URL;

    NSURLRequest *request = [NSURLRequest requestWithURL:_URL];
    [(UIWebView *)[self browserWebView] loadRequest:request];

    [self updateToolbarItems];
}

- (UIBarButtonItem *)backBarButtonItem {
    if (!backBarButtonItem) {
        backBarButtonItem = [[UIBarButtonItem alloc] initWithImage:[UIImage imageNamed:@"BrowserBackButton"] style:UIBarButtonItemStylePlain target:self action:@selector(goBackClicked)];
        [backBarButtonItem setImageInsets:UIEdgeInsetsMake(2, 0, -2, 0)];
		[backBarButtonItem setWidth:18];
    }

    return backBarButtonItem;
}

- (UIBarButtonItem *)forwardBarButtonItem {
    if (!forwardBarButtonItem) {
        forwardBarButtonItem = [[UIBarButtonItem alloc] initWithImage:[UIImage imageNamed:@"BrowserForwardButton"] style:UIBarButtonItemStylePlain target:self action:@selector(goForwardClicked)];
        [forwardBarButtonItem setImageInsets:UIEdgeInsetsMake(2, 0, -2, 0)];
		[forwardBarButtonItem setWidth:18];
    }

    return forwardBarButtonItem;
}

- (UIBarButtonItem *)refreshBarButtonItem {
    if (!refreshBarButtonItem) {
        refreshBarButtonItem = [[UIBarButtonItem alloc] initWithBarButtonSystemItem:UIBarButtonSystemItemRefresh target:self action:@selector(reloadClicked)];
    }

    return refreshBarButtonItem;
}

- (UIBarButtonItem *)stopBarButtonItem {
    if (!stopBarButtonItem) {
        stopBarButtonItem = [[UIBarButtonItem alloc] initWithBarButtonSystemItem:UIBarButtonSystemItemStop target:self action:@selector(stopClicked)];
    }

    return stopBarButtonItem;
}

#pragma mark - Initialization

- (id)initWithURL:(NSURL *)URL {
    self = [super initWithNibName:[[SVWebViewController class] description] bundle:nil];
    if (self) {
        _URL = URL;
    }

    return self;
}

#pragma mark - Navigation toolbar

- (void)updateToolbarItems {
    [[self backBarButtonItem] setEnabled:[(UIWebView *)[self browserWebView] canGoBack]];
    [[self forwardBarButtonItem] setEnabled:[(UIWebView *)[self browserWebView] canGoForward]];

    UIBarButtonItem *refreshStopBarButtonItem = [(UIWebView *)[self browserWebView] isLoading] ? [self stopBarButtonItem] : [self refreshBarButtonItem];

    UIBarButtonItem *flexibleSpaceBarButtonItem = [[UIBarButtonItem alloc] initWithBarButtonSystemItem:UIBarButtonSystemItemFlexibleSpace target:nil action:nil];

    [[self navigationToolbar] setItems:@[ flexibleSpaceBarButtonItem, [self backBarButtonItem], flexibleSpaceBarButtonItem, [self forwardBarButtonItem], flexibleSpaceBarButtonItem, refreshStopBarButtonItem, flexibleSpaceBarButtonItem ] animated:YES];
}

#pragma mark - Web view delegate

- (void)webViewDidStartLoad:(UIWebView *)webView {
	[[UIApplication sharedApplication] setNetworkActivityIndicatorVisible:YES];

    [self updateToolbarItems];
}


- (void)webViewDidFinishLoad:(UIWebView *)webView {
	[[UIApplication sharedApplication] setNetworkActivityIndicatorVisible:NO];

    [[self navigationItem] setTitle:[webView stringByEvaluatingJavaScriptFromString:@"document.title"]];

    [self updateToolbarItems];
}

- (void)webView:(UIWebView *)webView didFailLoadWithError:(NSError *)error {
	[[UIApplication sharedApplication] setNetworkActivityIndicatorVisible:NO];

    [self updateToolbarItems];
}

#pragma mark - Button actions

- (void)goBackClicked {
    [(UIWebView *)[self browserWebView] goBack];
}

- (void)goForwardClicked {
    [(UIWebView *)[self browserWebView] goForward];
}

- (void)reloadClicked {
    [(UIWebView *)[self browserWebView] reload];
}

- (void)stopClicked {
    [(UIWebView *)[self browserWebView] stopLoading];
	[self updateToolbarItems];
}

- (void)close {
    [self dismissViewControllerAnimated:YES completion:nil];
}

#pragma mark - View lifecycle

- (void)viewDidLoad {
    [super viewDidLoad];

    [self setEdgesForExtendedLayout:UIRectEdgeLeft | UIRectEdgeBottom | UIRectEdgeRight];

    NSURLRequest *request = [NSURLRequest requestWithURL:[self URL]];
    [(UIWebView *)[self browserWebView] loadRequest:request];

    [[self browserWebView] setProgressBlock:^(float progress) {
        [[self browserProgressView] setProgress:progress];

        double delayInSeconds = 1.0;
        dispatch_time_t popTime = dispatch_time(DISPATCH_TIME_NOW, (int64_t)(delayInSeconds * NSEC_PER_SEC));
        dispatch_after(popTime, dispatch_get_main_queue(), ^(void){
            if (progress == 1) {
                [[self browserProgressView] setHidden:YES];
            } else {
                [[self browserProgressView] setHidden:NO];
            }
        });
    }];

	[self updateToolbarItems];

    if ([self navigationController] && [[[self navigationController] viewControllers] count] == 1) {
        UIBarButtonItem *closeBarButtonItem = [[UIBarButtonItem alloc] initWithTitle:NSLocalizedString(@"CloseButton", @"Button titles") style:UIBarButtonItemStylePlain target:self action:@selector(close)];
        [[self navigationItem] setLeftBarButtonItem:closeBarButtonItem];
    }
}

- (void)dealloc {
    [(UIWebView *)[self browserWebView] stopLoading];
 	[[UIApplication sharedApplication] setNetworkActivityIndicatorVisible:NO];
    [[self browserWebView] setDelegate:nil];
}

@end
