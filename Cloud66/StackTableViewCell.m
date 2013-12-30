//
//  StackTableViewCell.m
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

#import <QuartzCore/QuartzCore.h>
#import "CSAppearanceManager.h"
#import "Stack.h"
#import "StackTableViewCell.h"

#pragma mark StackTableViewCell (Private)

@interface StackTableViewCell ()

@property (strong, nonatomic) NSTimer *updateTimer;

@end

#pragma mark - StackTableViewCell

@implementation StackTableViewCell

#pragma mark - Getters/Setters

@synthesize updateTimer;

- (void)setStack:(Stack *)stack {
    _stack = nil;
    _stack = stack;

    if ([[[self swipeScrollView] gestureRecognizers] count] == 2) {
        UITapGestureRecognizer *tapGestureRecognizer = [[UITapGestureRecognizer alloc] initWithTarget:self action:@selector(scrollViewPressed)];
        [[self swipeScrollView] addGestureRecognizer:tapGestureRecognizer];
    }

    [[self favoriteImageView] setTintColor:[UIColor whiteColor]];
    [[self favoriteImageView] setAlpha:0.0];

    [[self nameLabel] setTextColor:[[CSAppearanceManager defaultManager] darkTextColor]];
    [[self statusLabel] setTextColor:[[CSAppearanceManager defaultManager] lightTextColor]];
    [[self extraLabel] setTextColor:[[CSAppearanceManager defaultManager] lightTextColor]];

    [[self nameLabel] setFont:[UIFont preferredFontForTextStyle:UIFontTextStyleHeadline]];
    [[self statusLabel] setFont:[UIFont preferredFontForTextStyle:UIFontTextStyleSubheadline]];
    [[self extraLabel] setFont:[UIFont preferredFontForTextStyle:UIFontTextStyleSubheadline]];

    UIImage *favoriteImage;
    if ([[stack favorite] boolValue]) {
        favoriteImage = [[UIImage imageNamed:@"FavoriteIcon"] imageWithRenderingMode:UIImageRenderingModeAlwaysTemplate];
    } else {
        favoriteImage = [[UIImage imageNamed:@"FavoriteIconSelected"] imageWithRenderingMode:UIImageRenderingModeAlwaysTemplate];
    }

    [[self favoriteImageView] setImage:favoriteImage];


    CATransition *animation = [CATransition animation];
    [animation setDuration:0.35];
    [animation setType:kCATransitionFade];
    [animation setTimingFunction:[CAMediaTimingFunction functionWithName:kCAMediaTimingFunctionEaseInEaseOut]];
    [[[self statusLabel] layer] addAnimation:animation forKey:@"changeTextTransition"];
    [[[self extraLabel] layer] addAnimation:animation forKey:@"changeTextTransition"];

    [[self nameLabel] setText:[stack name]];

    UIFontDescriptor *fontDescriptor = [UIFontDescriptor preferredFontDescriptorWithTextStyle:UIFontTextStyleSubheadline];
    UIFontDescriptor *boldFontDescriptor = [fontDescriptor fontDescriptorWithSymbolicTraits: UIFontDescriptorTraitBold];
    UIFont *boldFont = [UIFont fontWithDescriptor:boldFontDescriptor size:0.0];

    NSMutableAttributedString *statusString = [[NSMutableAttributedString alloc] initWithString:[NSString stringWithFormat:@"%@ - %@", [stack statusString], [stack lastActivityString]]];
    [statusString addAttribute:NSFontAttributeName value:boldFont range:NSMakeRange(0, [[stack statusString] length])];
    [[self statusLabel] setAttributedText:statusString];

    NSString *maintenance = @"";
    int length = 0;
    if ([[stack maintenanceMode] boolValue]) {
        maintenance = @"Maintenance Mode - ";
        length = [maintenance length] - 3;
    }
    NSMutableAttributedString *extraString = [[NSMutableAttributedString alloc] initWithString:[NSString stringWithFormat:@"%@%@", maintenance, [stack gitBranch]]];
    [extraString addAttribute:NSFontAttributeName value:boldFont range:NSMakeRange(0, length)];
    [extraString addAttribute:NSForegroundColorAttributeName value:[[CSAppearanceManager defaultManager] darkTextColor] range:NSMakeRange(0, length)];
    [[self extraLabel] setAttributedText:extraString];

    [UIView animateWithDuration:0.35 animations:^{
        [[[self healthView] layer] setBackgroundColor:[[stack healthColor] CGColor]];
    }];
}

#pragma mark - Last activity update

- (void)updateLastActivity {
    if (![self updateTimer]) {
        [self setUpdateTimer:[NSTimer scheduledTimerWithTimeInterval:60 target:self selector:@selector(updateLastActivity) userInfo:nil repeats:YES]];
    }

    UIFontDescriptor *fontDescriptor = [UIFontDescriptor preferredFontDescriptorWithTextStyle:UIFontTextStyleSubheadline];
    UIFontDescriptor *boldFontDescriptor = [fontDescriptor fontDescriptorWithSymbolicTraits: UIFontDescriptorTraitBold];
    UIFont *boldFont = [UIFont fontWithDescriptor:boldFontDescriptor size:0.0];

    NSMutableAttributedString *statusString = [[NSMutableAttributedString alloc] initWithString:[NSString stringWithFormat:@"%@ - %@", [[self stack] statusString], [[self stack] lastActivityString]]];
    [statusString addAttribute:NSFontAttributeName value:boldFont range:NSMakeRange(0, [[[self stack] statusString] length] + 1)];
    [[self statusLabel] setAttributedText:statusString];
}

- (void)removeUpdateTimer:(NSNotification *)notification {
    [[self updateTimer] invalidate];
    [self setUpdateTimer:nil];
}

#pragma mark - Initialization

- (id)initWithCoder:(NSCoder *)aDecoder {
    self = [super initWithCoder:aDecoder];
    if (self) {
        [self updateLastActivity];

        [[NSNotificationCenter defaultCenter] addObserver:self selector:@selector(updateLastActivity) name:UIApplicationDidBecomeActiveNotification object:nil];
        [[NSNotificationCenter defaultCenter] addObserver:self selector:@selector(removeUpdateTimer:) name:UIApplicationDidEnterBackgroundNotification object:nil];
    }

    return self;
}

#pragma mark - Favorite handling

- (void)scrollViewPressed {
    if (![self isHighlighted]) {
        [self setHighlighted:YES];

        double delayInSeconds = 0.15;
        dispatch_time_t popTime = dispatch_time(DISPATCH_TIME_NOW, (int64_t)(delayInSeconds * NSEC_PER_SEC));
        dispatch_after(popTime, dispatch_get_main_queue(), ^(void){
            [self setHighlighted:NO];
        });
    }

    if ([[[self containingTableView] delegate] respondsToSelector:@selector(tableView:didSelectRowAtIndexPath:)]){
        NSIndexPath *cellIndexPath = [[self containingTableView] indexPathForCell:self];
        [[[self containingTableView] delegate] tableView:[self containingTableView] didSelectRowAtIndexPath:cellIndexPath];
    }
}

- (void)layoutSubviews {
    [super layoutSubviews];

    [[self swipeScrollView] setContentSize:CGSizeMake(self.contentView.bounds.size.width + 1, self.contentView.bounds.size.height)];
}

- (void)scrollViewDidScroll:(UIScrollView *)scrollView {
    if (scrollView.contentOffset.x >= 0) {
        [scrollView setContentOffset:CGPointMake(0, 0)];

        return;
    }

    [[self favoriteImageView] setAlpha:fabsf(scrollView.contentOffset.x) / 34];

    if (scrollView.contentOffset.x <= -34) {
        [scrollView setContentOffset:CGPointMake(-34, 0)];
    }
}

- (void)scrollViewDidEndDragging:(UIScrollView *)scrollView willDecelerate:(BOOL)decelerate {
    if (scrollView.contentOffset.x == -34) {
        [[self stack] favorite:![[[self stack] favorite] boolValue]];
    }
}

#pragma mark - Selection

- (void)setHighlighted:(BOOL)highlighted animated:(BOOL)animated {
    [super setHighlighted:highlighted animated:animated];

    [[self healthView] setBackgroundColor:[[self stack] healthColor]];
}

- (void)setSelected:(BOOL)selected animated:(BOOL)animated {
    [super setSelected:selected animated:animated];

    [[self healthView] setBackgroundColor:[[self stack] healthColor]];
}

#pragma mark - Memory management

- (void)dealloc {
    [[self updateTimer] invalidate];
    [self setUpdateTimer:nil];

    [[NSNotificationCenter defaultCenter] removeObserver:self name:UIApplicationDidBecomeActiveNotification object:nil];
    [[NSNotificationCenter defaultCenter] removeObserver:self name:UIApplicationDidEnterBackgroundNotification object:nil];
}

@end
