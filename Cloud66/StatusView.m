//
//  StatusView.m
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

#import "SVWebViewController.h"
#import "Stack.h"
#import "StatusView.h"

#pragma mark StatusView (Private)

@interface StatusView ()

@property (strong, nonatomic) UIActivityIndicatorView *activityIndicatorView;
@property (strong, nonatomic) UIImageView *statusImageView;

@end

#pragma mark - StatusView

@implementation StatusView

#pragma mark - Getters/Setters

@synthesize activityIndicatorView;
@synthesize statusImageView;

- (void)setStatus:(CSStatus)status {
    _status = status;

    [statusImageView setTintColor:[Status colorForStatus:status]];
}

#pragma mark - Initialization

- (id)initWithStatus:(CSStatus)status {
    self = [super initWithFrame:CGRectMake(0, 0, 23, 23)];
    if (self) {
        [self setContentMode:UIViewContentModeRight];

        activityIndicatorView = [[UIActivityIndicatorView alloc] initWithActivityIndicatorStyle:UIActivityIndicatorViewStyleGray];
        [activityIndicatorView setHidesWhenStopped:YES];
        [self addSubview:activityIndicatorView];

        statusImageView = [[UIImageView alloc] initWithFrame:CGRectMake(0, 0, 23, 23)];
        [statusImageView setImage:[[UIImage imageNamed:@"StatusIcon"] imageWithRenderingMode:UIImageRenderingModeAlwaysTemplate]];
        [self addSubview:statusImageView];

        [activityIndicatorView setCenter:statusImageView.center];

        UITapGestureRecognizer *tapGestureRecognizer = [[UITapGestureRecognizer alloc] initWithTarget:self action:@selector(showStatus)];
        [self addGestureRecognizer:tapGestureRecognizer];
    }

    return self;
}

- (void)refresh {
    if ([[self activityIndicatorView] isAnimating]) {
        return;
    }

    [statusImageView setHidden:YES];
    [activityIndicatorView startAnimating];

    [Status statusForStack:[[self stack] uid] success:^(CSStatus status) {
        [self setStatus:status];

        [activityIndicatorView stopAnimating];
        [statusImageView setHidden:NO];
    } failure:^(NSError *error) {
        [self setStatus:CSStatusUnkknown];

        [activityIndicatorView stopAnimating];
        [statusImageView setHidden:NO];
    }];
}

- (void)showStatus {
    [[Mixpanel sharedInstance] track:@"Status" properties:@{ @"Screen" : @"Details" }];

    SVWebViewController *webViewController = [[SVWebViewController alloc] initWithURL:[NSURL URLWithString:CS_STATUS_ADDRESS]];
    UINavigationController *statusNavigationController = [[UINavigationController alloc] initWithRootViewController:webViewController];
    UIViewController *rootViewController = [[[UIApplication sharedApplication] keyWindow] rootViewController];
    [rootViewController presentViewController:statusNavigationController animated:YES completion:nil];
}

@end
