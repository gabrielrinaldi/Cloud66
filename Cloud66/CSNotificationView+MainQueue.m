//
//  CSNotificationView+MainQueue.m
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

#import "CSNotificationView+MainQueue.h"

#pragma mark CSNotificationView (MainQueue)

@implementation CSNotificationView (MainQueue)

#pragma mark - Main queue methods

+ (void)showInMainQueueAndInViewController:(UIViewController *)viewController style:(CSNotificationViewStyle)style message:(NSString *)message {
    dispatch_async(dispatch_get_main_queue(), ^{
        [CSNotificationView showInViewController:viewController style:style message:message];
    });
}

+ (void)showInMainQueueAndInViewController:(UIViewController *)viewController tintColor:(UIColor *)tintColor image:(UIImage *)image message:(NSString *)message duration:(NSTimeInterval)duration {
    dispatch_async(dispatch_get_main_queue(), ^{
        [CSNotificationView showInViewController:viewController tintColor:tintColor image:image message:message duration:duration];
    });
}

@end
