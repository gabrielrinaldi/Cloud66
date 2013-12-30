//
//  LoginViewController.m
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

#import "GRWebView.h"
#import "Stack.h"
#import "CSAPISessionManager.h"
#import "LoginViewController.h"

#pragma mark LoginViewController

@implementation LoginViewController

#pragma mark - Display

+ (LoginViewController *)show {
    return [LoginViewController showAnimated:YES];
}

+ (LoginViewController *)showAnimated:(BOOL)animated {
    UIWindow *window = [[UIApplication sharedApplication] keyWindow];
    return [LoginViewController showFromViewController:[window rootViewController] animated:animated];
}

+ (LoginViewController *)showFromViewController:(UIViewController *)viewController animated:(BOOL)animated {
    return [LoginViewController showFromViewController:viewController animated:animated autoDismiss:YES];
}

+ (LoginViewController *)showFromViewController:(UIViewController *)viewController animated:(BOOL)animated autoDismiss:(BOOL)dismiss {
    LoginViewController *loginViewController = [[LoginViewController alloc] initWithURL:[CSAPISessionManager oauthAuthorizeURL]];
    UINavigationController *loginNavigationController = [[UINavigationController alloc] initWithRootViewController:loginViewController];

    if (dismiss && [viewController presentedViewController]) {
        [viewController dismissViewControllerAnimated:animated completion:^{
            [viewController presentViewController:loginNavigationController animated:animated completion:nil];
        }];
    } else {
        [viewController presentViewController:loginNavigationController animated:animated completion:nil];
    }

    return loginViewController;
}

#pragma mark - View lifecycle

- (void)viewDidLoad {
    [super viewDidLoad];

    [[self navigationItem] setLeftBarButtonItem:nil];
    [[self browserProgressView] setProgress:1.0];
    [[self browserWebView] setProgressBlock:nil];

    [[NSNotificationCenter defaultCenter] addObserverForName:CSUserDidLoginNotification object:nil queue:[NSOperationQueue mainQueue] usingBlock:^(NSNotification *note) {
        [[Mixpanel sharedInstance] track:@"Login"];

        [Stack syncWithSuccess:nil failure:nil];

        [self dismissViewControllerAnimated:YES completion:nil];
    }];
}

@end
