//
//  StackDetailTableViewCell.m
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

#import "StatusView.h"
#import "StackDetailViewController.h"
#import "StackDetailTableViewCell.h"

#pragma mark StackDetailTableViewCell

@implementation StackDetailTableViewCell

- (void)setShowStatusView:(BOOL)showStatusView {
    if ([self shouldShowStatusView] == showStatusView) {
        return;
    }

    _showStatusView = showStatusView;
    [_statusView setHidden:!_showStatusView];

    if (_showStatusView) {
        [[self imageView] setImage:[[UIImage imageNamed:@"StatusIcon"] imageWithRenderingMode:UIImageRenderingModeAlwaysTemplate]];
    } else {
        [[self imageView] setImage:nil];
    }
}

#pragma mark - Initialization

- (id)initWithStyle:(UITableViewCellStyle)style reuseIdentifier:(NSString *)reuseIdentifier {
    self = [super initWithStyle:style reuseIdentifier:reuseIdentifier];
    if (self) {
        _statusView = [[StatusView alloc] initWithStatus:CSStatusUnkknown];
        [_statusView setHidden:YES];
        [[self contentView] addSubview:_statusView];

        [[self imageView] setTintColor:[UIColor clearColor]];
    }

    return self;
}

- (void)layoutSubviews {
    [super layoutSubviews];

    [[self statusView] setFrame:self.imageView.frame];
}

#pragma mark - Custom actions support

- (BOOL)canPerformAction:(SEL)action withSender:(id)sender {
    if (![self delegate]) {
        return NO;
    }

    UITableView *tableView = [[(StackDetailViewController *)[self delegate] stackTableViewController] tableView];

    return [[self delegate] tableView:tableView canPerformAction:action forRowAtIndexPath:[tableView indexPathForCell:self] withSender:sender];
}

- (BOOL)canBecomeFirstResponder {
    return YES;
}

- (void)forwardInvocation:(NSInvocation *)invocation {
	if (![self delegate]) {
		[self doesNotRecognizeSelector:[invocation selector]];
	}

	[invocation invokeWithTarget:[self delegate]];
}

- (NSMethodSignature*)methodSignatureForSelector:(SEL)selector {
	NSMethodSignature *signature = [super methodSignatureForSelector:selector];
	if (!signature) {
		signature = [[self delegate] methodSignatureForSelector:selector];
	}

	return signature;
}

@end
