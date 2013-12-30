//
//  Stack.h
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

typedef enum {
    CSStackStatusQueued = 0,
    CSStackStatusSuccess = 1,
    CSStackStatusFailed = 2,
    CSStackStatusAnalysing = 3,
    CSStackStatusAnalysed = 4,
    CSStackStatusQueuedForDeploying = 5,
    CSStackStatusDeploying = 6,
    CSStackStatusTerminalFailure = 7,
    CSStackStatusUnknown = INT_MAX
} CSStackStatus;

typedef enum {
    CSStackHealthUnknown = 0,
    CSStackHealthBuilding = 1,
    CSStackHealthPartial = 2,
    CSStackHealthOK = 3,
    CSStackHealthBroken = 4
} CSStackHealth;

#pragma mark Stack

@interface Stack : NSManagedObject

@property (strong, nonatomic) NSString *uid;
@property (strong, nonatomic) NSString *name;
@property (strong, nonatomic) NSString *git;
@property (strong, nonatomic) NSString *gitBranch;
@property (strong, nonatomic) NSString *environment;
@property (strong, nonatomic) NSString *cloud;
@property (strong, nonatomic) NSString *fqdn;
@property (strong, nonatomic) NSString *language;
@property (strong, nonatomic) NSString *framework;
@property (strong, nonatomic) NSString *section;
@property (strong, nonatomic) NSNumber *status;
@property (strong, nonatomic) NSNumber *health;
@property (strong, nonatomic) NSNumber *maintenanceMode;
@property (strong, nonatomic) NSNumber *favorite;
@property (strong, nonatomic) NSString *redeploymentHook;
@property (strong, nonatomic) NSDate *lastActivity;
@property (strong, nonatomic) NSDate *createdAt;
@property (strong, nonatomic) NSDate *updatedAt;
@property (strong, nonatomic) NSManagedObject *serverGroups;
@property (strong, nonatomic, readonly) UIColor *healthColor;
@property (strong, nonatomic, readonly) NSString *healthString;
@property (strong, nonatomic, readonly) NSString *lastActivityString;
@property (strong, nonatomic, readonly) NSString *statusString;
@property (strong, nonatomic, readonly) NSString *createdAtString;

+ (Stack *)stackWithUid:(NSString *)uid;
+ (void)syncWithSuccess:(void (^)(BOOL hasNewData))success failure:(void (^)(NSError *error))failure;
- (void)updateWithSuccess:(void (^)(BOOL hasNewData))success failure:(void (^)(NSError *error))failure;
- (void)setMaintenanceModeEnabled:(BOOL)enabled success:(void (^)())success failure:(void (^)(NSError *error))failure;
- (void)redeployWithSuccess:(void (^)())success failure:(void (^)(NSError *error))failure;
- (BOOL)updateWithDictionary:(NSDictionary *)stackDictionary;
- (void)favorite:(BOOL)favorite;

@end
