//
//  Stack.m
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

#import <FormatterKit/TTTTimeIntervalFormatter.h>
#import "CSAppearanceManager.h"
#import "CSAPISessionManager.h"
#import "Stack.h"

#pragma mark Stack

@implementation Stack

#pragma mark - Getters/Setters

@dynamic uid;
@dynamic name;
@dynamic git;
@dynamic gitBranch;
@dynamic environment;
@dynamic cloud;
@dynamic fqdn;
@dynamic language;
@dynamic framework;
@dynamic section;
@dynamic status;
@dynamic health;
@dynamic maintenanceMode;
@dynamic favorite;
@dynamic redeploymentHook;
@dynamic lastActivity;
@dynamic createdAt;
@dynamic updatedAt;
@dynamic serverGroups;

- (NSString *)createdAtString {
    TTTTimeIntervalFormatter *timeIntervalFormatter = [TTTTimeIntervalFormatter new];
    [timeIntervalFormatter setPresentTimeIntervalMargin:60];
    return [timeIntervalFormatter stringForTimeInterval:[[self createdAt] timeIntervalSinceNow]];
}

- (UIColor *)healthColor {
    switch ([[self health] integerValue]) {
        case CSStackHealthOK:
            return [[CSAppearanceManager defaultManager] greenColor];

        case CSStackHealthPartial:
            return [[CSAppearanceManager defaultManager] yellowColor];

        case CSStackHealthBuilding:
            return [[CSAppearanceManager defaultManager] tintColor];

        case CSStackHealthBroken:
            return [[CSAppearanceManager defaultManager] redColor];

        default:
            return [[CSAppearanceManager defaultManager] lightTextColor];
    }
}

- (NSString *)healthString {
    switch ([[self health] intValue]) {
        case CSStackHealthBroken:
            return NSLocalizedString(@"HLT_BROKEN", @"Stack health");

        case CSStackHealthBuilding:
            return NSLocalizedString(@"HLT_BUILDING", @"Stack health");

        case CSStackHealthOK:
            return NSLocalizedString(@"HLT_OK", @"Stack health");

        case CSStackHealthPartial:
            return NSLocalizedString(@"HLT_PARTIAL", @"Stack health");

        default:
            return NSLocalizedString(@"HLT_UNKNOWN", @"Stack health");
    }
}

- (NSString *)lastActivityString {
    TTTTimeIntervalFormatter *timeIntervalFormatter = [TTTTimeIntervalFormatter new];
    [timeIntervalFormatter setPresentTimeIntervalMargin:60];
    return [timeIntervalFormatter stringForTimeInterval:[[self lastActivity] timeIntervalSinceNow]];
}

- (NSString *)statusString {
    switch ([[self status] intValue]) {
        case CSStackStatusQueued:
            return NSLocalizedString(@"STK_QUEUED", @"Stack status");

        case CSStackStatusSuccess:
            return NSLocalizedString(@"STK_SUCCESS", @"Stack status");

        case CSStackStatusFailed:
            return NSLocalizedString(@"STK_FAILED", @"Stack status");

        case CSStackStatusAnalysing:
            return NSLocalizedString(@"STK_ANALYSING", @"Stack status");

        case CSStackStatusAnalysed:
            return NSLocalizedString(@"STK_ANALYSED", @"Stack status");

        case CSStackStatusQueuedForDeploying:
            return NSLocalizedString(@"STK_QUEUED_FOR_DEPLOYING", @"Stack status");

        case CSStackStatusDeploying:
            return NSLocalizedString(@"STK_DEPLOYING", @"Stack status");

        case CSStackStatusTerminalFailure:
            return NSLocalizedString(@"STK_TERMINAL_FAILURE", @"Stack status");
            
        default:
            return NSLocalizedString(@"STK_UNKNOWN", @"Stack status");
    }
}

#pragma mark - Helpers

+ (Stack *)stackWithUid:(NSString *)uid {
    NSError *error;
    NSFetchRequest *request = [[NSFetchRequest alloc] initWithEntityName:@"Stack"];
    [request setPredicate:[NSPredicate predicateWithFormat:@"uid = %@", uid]];

    NSArray *stacks = [[CSAppDelegate managedObjectContext] executeFetchRequest:request error:&error];

    if (!error && [stacks count] > 0) {
        return [stacks lastObject];
    }
    
    return nil;
}

#pragma mark - API

+ (void)syncWithSuccess:(void (^)(BOOL hasNewData))success failure:(void (^)(NSError *error))failure {
    [[CSAPISessionManager sharedManager] GET:@"stacks" parameters:nil success:^(NSURLSessionDataTask *task, id responseObject) {
        dispatch_async(dispatch_get_global_queue(DISPATCH_QUEUE_PRIORITY_LOW, 0), ^{
            NSManagedObjectContext *managedObjectContext = [[NSManagedObjectContext alloc] initWithConcurrencyType:NSPrivateQueueConcurrencyType];
            [managedObjectContext setPersistentStoreCoordinator:[[CSAppDelegate managedObjectContext] persistentStoreCoordinator]];

            NSError *error;
            NSFetchRequest *request = [NSFetchRequest fetchRequestWithEntityName:@"Stack"];
            [request setPropertiesToFetch:@[ @"uid" ]];
            NSMutableSet *cachedStacks = [[NSMutableSet alloc] initWithArray:[managedObjectContext executeFetchRequest:request error:&error]];

            if (!cachedStacks || error) {
                [[Mixpanel sharedInstance] trackErrorInClass:[[Stack class] description] function:__PRETTY_FUNCTION__ line:__LINE__ type:[NSString stringWithFormat:@"Fetch-%d", [error code]]];

                if (failure) {
                    failure(error);
                }

                return;
            }

            [managedObjectContext performBlock:^{
                BOOL isDirty = NO;
                for (NSDictionary *stackDictionary in [responseObject objectForKey:@"response"]) {
                    NSString *uid = [stackDictionary objectForKey:@"uid"];
                    NSPredicate *predicate = [NSPredicate predicateWithFormat:@"uid = %@", uid];

                    Stack *stack;
                    NSSet *foundStacks = [cachedStacks filteredSetUsingPredicate:predicate];
                    if ([foundStacks count] == 0) {
                        NSEntityDescription *entity = [NSEntityDescription entityForName:@"Stack" inManagedObjectContext:managedObjectContext];
                        stack = [[Stack alloc] initWithEntity:entity insertIntoManagedObjectContext:managedObjectContext];
                        [stack setUid:uid];
                        isDirty = YES;
                    } else {
                        stack = [foundStacks anyObject];
                        [cachedStacks removeObject:stack];
                    }

                    if ([stack updateWithDictionary:stackDictionary]) {
                        isDirty = YES;
                    }
                }

                for (Stack *aStack in cachedStacks) {
                    isDirty = YES;
                    [managedObjectContext deleteObject:aStack];
                }

                if (isDirty) {
                    NSError *error;
                    if (![managedObjectContext save:&error] || error) {
                        [[Mixpanel sharedInstance] trackErrorInClass:[[Stack class] description] function:__PRETTY_FUNCTION__ line:__LINE__ type:[NSString stringWithFormat:@"Save-%d", [error code]]];

                        if (failure) {
                            failure(error);
                        }

                        return;
                    }
                }

                if (success) {
                    success(isDirty);
                }
            }];
        });
    } failure:^(NSURLSessionDataTask *task, NSError *error) {
        [[Mixpanel sharedInstance] trackErrorInClass:[[Stack class] description] function:__PRETTY_FUNCTION__ line:__LINE__ type:[NSString stringWithFormat:@"HTTP-%d", [error code]]];

        if (failure) {
            failure(error);
        }
    }];
}

- (void)updateWithSuccess:(void (^)(BOOL hasNewData))success failure:(void (^)(NSError *error))failure {
    [[CSAPISessionManager sharedManager] GET:[NSString stringWithFormat:@"stacks/%@", [self uid]] parameters:nil success:^(NSURLSessionDataTask *task, id responseObject) {
        dispatch_async(dispatch_get_global_queue(DISPATCH_QUEUE_PRIORITY_LOW, 0), ^{
            NSDictionary *stackDictionary = [responseObject objectForKey:@"response"];

            NSManagedObjectID *stackID = [self objectID];
            NSManagedObjectContext *managedObjectContext = [[NSManagedObjectContext alloc] initWithConcurrencyType:NSPrivateQueueConcurrencyType];
            [managedObjectContext setPersistentStoreCoordinator:[[CSAppDelegate managedObjectContext] persistentStoreCoordinator]];

            [managedObjectContext performBlock:^{
                BOOL isDirty = NO;
                Stack *stack = (Stack *)[managedObjectContext objectWithID:stackID];
                isDirty = [stack updateWithDictionary:stackDictionary];

                if (isDirty) {
                    NSError *error;
                    if (![managedObjectContext save:&error] || error) {
                        [[Mixpanel sharedInstance] trackErrorInClass:[[Stack class] description] function:__PRETTY_FUNCTION__ line:__LINE__ type:[NSString stringWithFormat:@"Save-%d", [error code]]];

                        if (failure) {
                            failure(error);
                        }

                        return;
                    }
                }

                dispatch_sync(dispatch_get_main_queue(), ^{
                    [[self managedObjectContext] refreshObject:self mergeChanges:YES];
                });

                if (success) {
                    success(isDirty);
                }
            }];
        });
    } failure:^(NSURLSessionDataTask *task, NSError *error) {
        [[Mixpanel sharedInstance] trackErrorInClass:[[Stack class] description] function:__PRETTY_FUNCTION__ line:__LINE__ type:[NSString stringWithFormat:@"HTTP-%d", [error code]]];

        if (failure) {
            failure(error);
        }
    }];
}

- (void)setMaintenanceModeEnabled:(BOOL)enabled success:(void (^)())success failure:(void (^)(NSError *error))failure {
    NSString *value = (enabled) ? @"1" : @"0";
    [[CSAPISessionManager sharedManager] POST:[NSString stringWithFormat:@"stacks/%@/maintenance_mode", [self uid]] parameters:@{ @"value" : value } success:^(NSURLSessionDataTask *task, id responseObject) {
        [self updateWithSuccess:^(BOOL hasNewData) {
            if (success) {
                success();
            }
        } failure:^(NSError *error) {
            if (failure) {
                failure(error);
            }
        }];
    } failure:^(NSURLSessionDataTask *task, NSError *error) {
        [[Mixpanel sharedInstance] trackErrorInClass:[[Stack class] description] function:__PRETTY_FUNCTION__ line:__LINE__ type:[NSString stringWithFormat:@"HTTP-%d", [error code]]];

        if (failure) {
            failure(error);
        }
    }];
}

- (void)redeployWithSuccess:(void (^)())success failure:(void (^)(NSError *error))failure {
    [[CSAPISessionManager sharedManager] POST:[NSString stringWithFormat:@"stacks/%@/redeploy", [self uid]] parameters:nil success:^(NSURLSessionDataTask *task, id responseObject) {
        [self updateWithSuccess:^(BOOL hasNewData) {
            if (success) {
                success();
            }
        } failure:^(NSError *error) {
            if (failure) {
                failure(error);
            }
        }];
    } failure:^(NSURLSessionDataTask *task, NSError *error) {
        [[Mixpanel sharedInstance] trackErrorInClass:[[Stack class] description] function:__PRETTY_FUNCTION__ line:__LINE__ type:[NSString stringWithFormat:@"HTTP-%d", [error code]]];

        if (failure) {
            failure(error);
        }
    }];
}

#pragma mark - Parsing

- (BOOL)updateWithDictionary:(NSDictionary *)stackDictionary {
    BOOL isDirty = NO;

    for (NSAttributeDescription *attribute in [[self entity] properties]) {
        if ([attribute isKindOfClass:[NSRelationshipDescription class]] || ![[attribute userInfo] objectForKey:@"key"]) {
            continue;
        }

        if ([[attribute attributeValueClassName] isEqualToString:@"NSDate"]) {
            if ([stackDictionary objectForKey:[[attribute userInfo] objectForKey:@"key"]] == [NSNull null]) {
                if ([self setValue:nil ifDifferentForKey:[attribute name]]) {
                    isDirty = YES;
                }
                
                continue;
            }
            
            NSDateFormatter *dateFormatter = [NSDateFormatter new];
            [dateFormatter setDateFormat:@"yyyy-MM-dd'T'HH:mm:ssZZZZZ"];
            
            NSDate *date = [dateFormatter dateFromString:[stackDictionary objectForKey:[[attribute userInfo] objectForKey:@"key"]]];
            if (!date) {
                [dateFormatter setDateFormat:@"yyyy-MM-dd HH:mm:ss zzz"];
                date = [dateFormatter dateFromString:[stackDictionary objectForKey:[[attribute userInfo] objectForKey:@"key"]]];
            } else if (!date) {
                [dateFormatter setDateFormat:@"yyyy-MM-dd'T'HH:mm:ssz"];
                date = [dateFormatter dateFromString:[stackDictionary objectForKey:[[attribute userInfo] objectForKey:@"key"]]];
            }

            if ([self setValue:date ifDifferentForKey:[attribute name]]) {
                isDirty = YES;
            }
        } else {
            if ([[attribute name] isEqualToString:@"cloud"]) {
                NSString *cloud;
                if (![[stackDictionary objectForKey:@"cloud"] isEqualToString:@"no_cloud"]) {
                    cloud = [stackDictionary objectForKey:@"cloud"];
                }

                if ([self setValue:cloud ifDifferentForKey:[attribute name]]) {
                    isDirty = YES;
                }
            } else {
                if ([self setValue:[stackDictionary objectForKey:[[attribute userInfo] objectForKey:@"key"]] ifDifferentForKey:[attribute name]]) {
                    isDirty = YES;
                }
            }
        }
    }

    if (isDirty && ![[self favorite] boolValue]) {
        [self setSection:[self environment]];
    }

    return isDirty;
}

- (BOOL)setValue:(id)value ifDifferentForKey:(NSString *)key {
    if ((value && ![self valueForKey:key]) || (!value && [self valueForKey:key])) {
        [self setValue:value forKey:key];

        return YES;
    }

    if ([value isKindOfClass:[NSString class]] && [value isEqualToString:[self valueForKey:key]]) {
        return NO;
    } else if ([value isKindOfClass:[NSNumber class]] && [value isEqualToNumber:[self valueForKey:key]]) {
        return NO;
    } else if ([value isKindOfClass:[NSDate class]] && [value isEqualToDate:[self valueForKey:key]]) {
        return NO;
    } else if ([value isEqual:[self valueForKey:key]]) {
        return NO;
    }

    [self setValue:value forKey:key];

    return YES;
}

#pragma mark - Favorite handling

- (void)favorite:(BOOL)favorite {
    if ([[self favorite] boolValue] == favorite) {
        return;
    }

    dispatch_async(dispatch_get_global_queue(DISPATCH_QUEUE_PRIORITY_LOW, 0), ^{
        NSManagedObjectID *stackID = [self objectID];
        NSManagedObjectContext *managedObjectContext = [[NSManagedObjectContext alloc] initWithConcurrencyType:NSPrivateQueueConcurrencyType];
        [managedObjectContext setPersistentStoreCoordinator:[[CSAppDelegate managedObjectContext] persistentStoreCoordinator]];

        [managedObjectContext performBlock:^{
            Stack *stack = (Stack *)[managedObjectContext objectWithID:stackID];
            [stack setFavorite:[NSNumber numberWithBool:favorite]];
            if (favorite) {
                [stack setSection:@"FavoriteStackSection"];
            } else {
                [stack setSection:[stack environment]];
            }

            NSError *error;
            if (![managedObjectContext save:&error] || error) {
                [[Mixpanel sharedInstance] trackErrorInClass:[[Stack class] description] function:__PRETTY_FUNCTION__ line:__LINE__ type:[NSString stringWithFormat:@"Save-%d", [error code]]];
            }
        }];
    });
}

@end
