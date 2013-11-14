//
//  OfflineTests.m
//  KinveyKit
//
//  Created by Michael Katz on 11/12/13.
//  Copyright (c) 2013 Kinvey. All rights reserved.
//
// This software is licensed to you under the Kinvey terms of service located at
// http://www.kinvey.com/terms-of-use. By downloading, accessing and/or using this
// software, you hereby accept such terms of service  (and any agreement referenced
// therein) and agree that you have read, understand and agree to be bound by such
// terms of service and are of legal age to agree to such terms with Kinvey.
//
// This software contains valuable confidential and proprietary information of
// KINVEY, INC and is subject to applicable licensing agreements.
// Unauthorized reproduction, transmission or distribution of this file and its
// contents is a violation of applicable laws.
//

#import <SenTestingKit/SenTestingKit.h>

#import "TestUtils2.h"

#import "KinveyCoreInternal.h"
#import "KinveyDataStoreInternal.h"

@interface KCSUser (TestUtils)
+ (void) mockUser;
@end

@implementation KCSUser (TestUtils)
+ (void)mockUser
{
    KCSUser* user = [[KCSUser alloc] init];
    user.username = @"mock";
    user.password = @"mock";
    user.sessionAuth = @"mock";
#pragma clang diagnostic push
#pragma clang diagnostic ignored "-Wdeprecated"
    [KCSClient sharedClient].currentUser = user;
#pragma clang diagnostic pop
}

@end


@interface OfflineDelegate : NSObject <KCSOfflineUpdateDelegate>
@property (atomic) BOOL shouldSaveCalled;
@property (atomic) BOOL willSaveCalled;
@property (atomic) BOOL didSaveCalled;
@property (atomic) BOOL shouldEnqueueCalled;
@property (atomic) NSUInteger didEnqueCalledCount;
@property (atomic, retain) NSError* error;
@property (nonatomic, copy) void (^callback)(void);
@end
@implementation OfflineDelegate

- (BOOL)shouldSaveObject:(NSString *)objectId inCollection:(NSString *)collectionName lastAttemptedSaveTime:(NSDate *)saveTime
{
    self.shouldSaveCalled = YES;
    return YES;
}

- (void)willSaveObject:(NSString *)objectId inCollection:(NSString *)collectionName
{
    self.willSaveCalled = YES;
}

- (void)didSaveObject:(NSString *)objectId inCollection:(NSString *)collectionName
{
    self.didSaveCalled = YES;
    _callback();
}

- (BOOL)shouldEnqueueObject:(NSString *)objectId inCollection:(NSString *)collectionName onError:(NSError *)error
{
    self.shouldEnqueueCalled = YES;
    self.error = error;
    
    return YES;
}

- (void)didEnqueueObject:(NSString *)objectId inCollection:(NSString *)collectionName
{
    self.didEnqueCalledCount++;
    _callback();
}

@end

@interface OfflineTests : SenTestCase
@property (nonatomic, strong) KCSOfflineUpdate* update;
@property (nonatomic, strong) KCSEntityPersistence* cache;
@property (nonatomic, strong) OfflineDelegate* delegate;
@end

@implementation OfflineTests

- (void)setUp
{
    [super setUp];
    [KCSUser mockUser];
    
    self.cache = [[KCSEntityPersistence alloc] initWithPersistenceId:@"offlinetests"];
    [self.cache clearCaches];
    self.delegate = [[OfflineDelegate alloc] init];
    @weakify(self);
    self.delegate.callback = ^{
        @strongify(self);
        self.done = YES;
    };
    
    self.update = [[KCSOfflineUpdate alloc] initWithCache:self.cache];
    self.update.delegate = self.delegate;
    self.update.useMock = YES;
}

- (void)tearDown
{
    // Put teardown code here; it will be run once, after the last test case.
    [super tearDown];
}

- (void) testBasic
{
    NSDictionary* entity = @{@"a":@"x"};
    [self.update addObject:entity route:@"R" collection:@"C" headers:@{KCSRequestLogMethod} method:@"POST" error:nil];
    
    [self.update start];
    self.done = NO;
    [self poll];
    
    STAssertEquals([self.cache unsavedCount], (int)0, @"should be zero");
}

- (void) testRestartNotConnected
{
    [KCSMockServer sharedServer].offline = YES;
       
    NSDictionary* entity = @{@"a":@"x"};
    [self.update addObject:entity route:@"R" collection:@"C" headers:@{KCSRequestLogMethod} method:@"POST" error:nil];
    
    [self.update start];
    self.done = NO;
    [self poll];
    
    STAssertFalse(self.delegate.didSaveCalled, @"should not have been saved");
    KTAssertEqualsInt(self.delegate.didEnqueCalledCount, 2);
    
    STAssertEquals([self.cache unsavedCount], (int)1, @"should be one");
}


- (void) testSaveKickedOff
{
    [KCSMockServer sharedServer].offline = YES;
    
    NSDictionary* entity = @{@"a":@"x"};
    [self.update addObject:entity route:@"R" collection:@"C" headers:@{KCSRequestLogMethod} method:@"POST" error:nil];
    
    self.done = NO;
    [self.update start];
    [self poll];
    STAssertFalse(self.delegate.didSaveCalled, @"should not have been saved");
    STAssertEquals([self.cache unsavedCount], (int)1, @"should be one");


    self.done = NO;
    [KCSMockServer sharedServer].offline = NO;
    [KCSMockReachability changeReachability:YES];
    [self poll];
    
    STAssertEquals([self.cache unsavedCount], (int)0, @"should be zero");
    STAssertTrue(self.delegate.didSaveCalled, @"should not have been saved");
}

@end
