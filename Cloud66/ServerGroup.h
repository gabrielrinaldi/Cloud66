//
//  ServerGroup.h
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
    CSServerGroupTypeWebServerGroup = 0,
    CSServerGroupTypeDatabaseServerGroup = 1,
    CSServerGroupTypeHAProxyServerGroup = 2,
    CSServerGroupTypeRedisServerGroup = 3,
    CSServerGroupTypeUnknown = INT_MAX
} CSServerGroupType;

typedef enum {
    CSServerGroupSubtypeRailsServers = 0,
    CSServerGroupSubtypeMySQLServers = 1,
    CSServerGroupSubtypePostgreSQLServers = 2,
    CSServerGroupSubtypeMongoDBServers = 3,
    CSServerGroupSubtypeHAProxyServers = 4,
    CSServerGroupSubtypeRedisServers = 5,
    CSServerGroupSubtypeUnknown = INT_MAX
} CSServerGroupSubtype;

@class Stack;

#pragma mark ServerGroup

@interface ServerGroup : NSManagedObject

@property (strong, nonatomic) NSNumber *rid;
@property (strong, nonatomic) NSString *name;
@property (strong, nonatomic) NSNumber *type;
@property (strong, nonatomic) NSNumber *subType;
@property (strong, nonatomic) NSDate *createdAt;
@property (strong, nonatomic) NSDate *updatedAt;
@property (strong, nonatomic) NSManagedObject *servers;
@property (strong, nonatomic) Stack *stack;

@end
