//
//  CSAppearanceManager.m
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

#pragma mark CSAppearanceManager

@implementation CSAppearanceManager

#pragma mark - Getters/Setters

- (UIColor *)lightTextColor {
    return [UIColor colorWithRed:0.40 green:0.40 blue:0.40 alpha:1.0];
}

- (UIColor *)darkTextColor {
    return [UIColor colorWithRed:0.18 green:0.18 blue:0.18 alpha:1.0];
}

- (UIColor *)backgroundColor {
    return [UIColor colorWithRed:0.90 green:0.92 blue:0.94 alpha:1.0];
}

- (UIColor *)tintColor {
    return [UIColor colorWithRed:0.19 green:0.44 blue:0.70 alpha:1.0];
}

- (UIColor *)greenColor {
    return [UIColor colorWithRed:0.27 green:0.73 blue:0.36 alpha:1.0];
}

- (UIColor *)yellowColor {
    return [UIColor colorWithRed:0.98 green:0.89 blue:0.20 alpha:1.0];
}

- (UIColor *)redColor {
    return [UIColor colorWithRed:0.94 green:0.12 blue:0.10 alpha:1.0];
}

#pragma mark - Default manager

+ (instancetype)defaultManager {
    static CSAppearanceManager *_defaultManager = nil;
    static dispatch_once_t onceToken;
    dispatch_once(&onceToken, ^{
        _defaultManager = [CSAppearanceManager new];
    });

    return _defaultManager;
}

#pragma mark - Initialization

- (id)init {
    self = [super init];
    if (self) {
        [[UINavigationBar appearance] setTitleTextAttributes:@{ NSForegroundColorAttributeName : [self darkTextColor] }];
    }

    return self;
}

@end
