//
//  Status.m
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
#import "CSAPISessionManager.h"
#import "Status.h"

#pragma mark Status

@implementation Status

#pragma mark - Helpers

+ (UIColor *)colorForStatus:(CSStatus)status {
    switch (status) {
        case CSStatusHealthy:
            return [[CSAppearanceManager defaultManager] greenColor];
            break;

        case CSStatusPartial:
            return [[CSAppearanceManager defaultManager] yellowColor];
            break;

        case CSStatusFaulty:
            return [[CSAppearanceManager defaultManager] redColor];
            break;

        case CSStatusMaintenance:
            return [[CSAppearanceManager defaultManager] tintColor];
            break;

        default:
            return [[CSAppearanceManager defaultManager] lightTextColor];
            break;
    }
}

+ (CSStatus)statusForString:(NSString *)status {
    if ([[status lowercaseString] isEqualToString:@"healthy"]) {
        return CSStatusHealthy;
    } else if ([[status lowercaseString] isEqualToString:@"partial"]) {
        return CSStatusPartial;
    } else if ([[status lowercaseString] isEqualToString:@"faulty"]) {
        return CSStatusFaulty;
    } else if ([[status lowercaseString] isEqualToString:@"maintenance"]) {
        return CSStatusMaintenance;
    } else {
        return CSStatusUnkknown;
    }
}

#pragma mark - API

+ (void)statusWithSuccess:(void (^)(CSStatus status))success failure:(void (^)(NSError *error))failure {
    [[CSAPISessionManager sharedManager] GET:@"users/cloud_status" parameters:nil success:^(NSURLSessionDataTask *task, id responseObject) {
        if (success) {
            success([Status statusForString:[responseObject objectForKey:@"response"]]);
        }
    } failure:^(NSURLSessionDataTask *task, NSError *error) {
        if (failure) {
            failure(error);
        }
    }];
}

+ (void)statusForStack:(NSString *)stack success:(void (^)(CSStatus status))success failure:(void (^)(NSError *error))failure {
    [[CSAPISessionManager sharedManager] GET:[NSString stringWithFormat:@"stacks/%@/status", stack] parameters:nil success:^(NSURLSessionDataTask *task, id responseObject) {
        if (success) {
            success([Status statusForString:[responseObject objectForKey:@"response"]]);
        }
    } failure:^(NSURLSessionDataTask *task, NSError *error) {
        if (failure) {
            failure(error);
        }
    }];
}

@end
