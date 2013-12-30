//
//  GRAlertView.m
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

#import "GRAlertView.h"

typedef void (^GRAlertBlock)();

#pragma mark GRAlertView (Private)

@interface GRAlertView ()

@property (strong, nonatomic) UIToolbar *backgroundToolbar;
@property (strong, nonatomic) UIView *alertView;
@property (strong, nonatomic) UILabel *titleLabel;
@property (strong, nonatomic) UILabel *messageLabel;
@property (strong, nonatomic) NSMutableArray *buttons;
@property (strong, nonatomic) GRAlertView *retainedSelf;
@property (strong, nonatomic) GRAlertBlock cancelBlock;
@property (strong, nonatomic) GRAlertBlock otherBlock;
@property (assign, nonatomic, getter = isVisible) BOOL visible;

@end

#pragma mark - GRAlertView

@implementation GRAlertView

#pragma mark - Getters/Setters

@synthesize backgroundToolbar;
@synthesize alertView;
@synthesize titleLabel;
@synthesize messageLabel;
@synthesize buttons;
@synthesize retainedSelf;
@synthesize cancelBlock;
@synthesize otherBlock;
@synthesize visible;

- (void)setTitle:(NSString *)title {
    if ([[self title] isEqualToString:title]) {
        return;
    }

    _title = [title copy];
    [[self titleLabel] setText:_title];
}

- (void)setMessage:(NSString *)message {
    if ([[self message] isEqualToString:message]) {
        return;
    }

    _message = [message copy];
    [[self messageLabel] setText:_message];
}

- (void)setCancelButtonWithTitle:(NSString *)title block:(void (^)())block {
    cancelBlock = block;

    UIButton *cancelButton = [[UIButton alloc] initWithFrame:CGRectZero];
    [cancelButton setTitle:title forState:UIControlStateNormal];
    [cancelButton setTitleColor:[[[UIApplication sharedApplication] keyWindow] tintColor] forState:UIControlStateNormal];
    [[cancelButton titleLabel] setFont:[UIFont preferredFontForTextStyle:UIFontTextStyleHeadline]];
    [cancelButton addTarget:self action:@selector(cancel) forControlEvents:UIControlEventTouchUpInside];

    [[self buttons] addObject:cancelButton];
}

- (void)setOtherButtonWithTitle:(NSString *)title block:(void (^)())block {
    otherBlock = block;

    UIButton *otherButton = [[UIButton alloc] initWithFrame:CGRectZero];
    [otherButton setTitle:title forState:UIControlStateNormal];
    [otherButton setTitleColor:[[[UIApplication sharedApplication] keyWindow] tintColor] forState:UIControlStateNormal];
    [[otherButton titleLabel] setFont:[UIFont preferredFontForTextStyle:UIFontTextStyleHeadline]];
    [otherButton addTarget:self action:@selector(other) forControlEvents:UIControlEventTouchUpInside];

    [[self buttons] addObject:otherButton];
}

#pragma mark - Initializers

- (id)initWithTitle:(NSString *)title {
    return [self initWithTitle:title message:nil];
}

- (id)initWithTitle:(NSString *)title message:(NSString *)message {
    self = [super init];
    if (self) {
        visible = NO;
        buttons = [NSMutableArray array];

        backgroundToolbar = [[UIToolbar alloc] initWithFrame:CGRectZero];
        [backgroundToolbar setTintColor:[UIColor colorWithWhite:0.80 alpha:0.80]];

        [self setTitle:title];
        [self setMessage:message];

        alertView = [[UIView alloc] initWithFrame:CGRectMake(0, 0, 270, 125)];
        [[alertView layer] setCornerRadius:10];
        [alertView setBackgroundColor:[UIColor whiteColor]];

        titleLabel = [[UILabel alloc] initWithFrame:CGRectMake(20, 20, 230, 30)];
        [titleLabel setBackgroundColor:[UIColor whiteColor]];
        [titleLabel setTextColor:[UIColor blackColor]];
        [titleLabel setTextAlignment:NSTextAlignmentCenter];
        [titleLabel setFont:[UIFont preferredFontForTextStyle:UIFontTextStyleHeadline]];
        [titleLabel setText:[self title]];
        [alertView addSubview:titleLabel];

        messageLabel = [[UILabel alloc] initWithFrame:CGRectMake(20, 50, 230, 30)];
        [messageLabel setBackgroundColor:[UIColor whiteColor]];
        [messageLabel setTextColor:[UIColor blackColor]];
        [messageLabel setTextAlignment:NSTextAlignmentCenter];
        [messageLabel setFont:[UIFont preferredFontForTextStyle:UIFontTextStyleBody]];
        [messageLabel setNumberOfLines:0];
        [messageLabel setText:[self message]];
        [alertView addSubview:messageLabel];

        [self setRetainedSelf:self];
    }

    return self;
}

#pragma mark - Button actions

- (void)cancel {
    if (cancelBlock) {
        cancelBlock();
    }

    [self hide];
}

- (void)other {
    if (otherBlock) {
        otherBlock();
    }

    [self hide];
}

#pragma mark - Display

- (void)show {
    if ([self isVisible]) {
        return;
    }

    visible = YES;

    UIWindow *keyWindow = [[UIApplication sharedApplication] keyWindow];

    [backgroundToolbar setFrame:keyWindow.bounds];
    [backgroundToolbar setAlpha:0.0];

    [titleLabel sizeToFit];
    [titleLabel setFrame:CGRectMake(titleLabel.frame.origin.x, titleLabel.frame.origin.y, 230, titleLabel.frame.size.height)];

    [messageLabel sizeToFit];
    [messageLabel setFrame:CGRectMake(messageLabel.frame.origin.x, titleLabel.frame.origin.y + titleLabel.frame.size.height + 5, 230, messageLabel.frame.size.height)];

    if ([[self buttons] count] > 0) {
        UIView *separatorView = [[UIView alloc] initWithFrame:CGRectMake(0, messageLabel.frame.origin.y + messageLabel.frame.size.height + 10, 270, 1)];
        [separatorView setBackgroundColor:[UIColor lightGrayColor]];
        [separatorView setAlpha:0.5];
        [alertView addSubview:separatorView];

        int width = 270 / [[self buttons] count];
        int i = 0;
        for (UIButton *button in [self buttons]) {
            [button setFrame:CGRectMake((i * width), messageLabel.frame.origin.y + messageLabel.frame.size.height + 10, width, 40)];
            [alertView addSubview:button];

            if ([[self buttons] count] > 0 && i < ([[self buttons] count] - 1)) {
                UIView *separatorView = [[UIView alloc] initWithFrame:CGRectMake(button.frame.origin.x + button.frame.size.width, button.frame.origin.y, 1, button.frame.size.height)];
                [separatorView setBackgroundColor:[UIColor lightGrayColor]];
                [separatorView setAlpha:0.5];
                [alertView addSubview:separatorView];
            }
            
            i++;
        }

        [[self alertView] setFrame:CGRectMake(0, 0, alertView.frame.size.width, messageLabel.frame.origin.y + messageLabel.frame.size.height + 50)];
    } else {
        [[self alertView] setFrame:CGRectMake(0, 0, alertView.frame.size.width, messageLabel.frame.origin.y + messageLabel.frame.size.height + 20)];
    }

    [alertView setAlpha:0.0];
    [alertView setCenter:CGPointMake(keyWindow.bounds.size.width / 2, keyWindow.bounds.size.height / 2)];
    [alertView setTransform:CGAffineTransformMakeScale(2, 2)];

    [keyWindow addSubview:backgroundToolbar];
    [keyWindow addSubview:alertView];

    [UIView animateWithDuration:0.25 animations:^{
        [backgroundToolbar setAlpha:1.0];

        [alertView setAlpha:1.0];
        [alertView setTransform:CGAffineTransformMakeScale(1, 1)];
    }];
}

- (void)hide {
    [UIView animateWithDuration:0.25 animations:^{
        [backgroundToolbar setAlpha:0.0];

        [alertView setAlpha:0.0];
        [alertView setTransform:CGAffineTransformMakeScale(0.5, 0.5)];
    } completion:^(BOOL finished) {
        [backgroundToolbar removeFromSuperview];
        backgroundToolbar = nil;

        [alertView removeFromSuperview];
        alertView = nil;

        [buttons removeAllObjects];
        buttons = nil;

        _title = nil;
        _message = nil;
        titleLabel = nil;
        messageLabel = nil;
        cancelBlock = nil;
        otherBlock = nil;
        retainedSelf = nil;
    }];
}

@end
