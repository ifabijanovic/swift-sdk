//
//  KCSMetadata.m
//  KinveyKit
//
//  Created by Michael Katz on 6/25/12.
//  Copyright (c) 2012 Kinvey. All rights reserved.
//

#import "KCSMetadata.h"
#import "NSDate+ISO8601.h"
#import "KCSClient.h"
#import "KinveyUser.h"

#define kKMDLMTKey @"lmt"
#define kACLCreatorKey @"creator"
#define kACLReadersKey @"r"
#define kACLWritersKey @"w"
#define kACLGlobalReadKey @"gr"
#define kACLGlobalWriteKey @"gw"

@interface KCSUser ()
- (NSString*) userId;
@end

@interface KCSMetadata ()
@property (nonatomic, retain, readonly) NSDate* lastModifiedTime;
@property (nonatomic, retain, readonly) NSMutableDictionary* acl;
@end

@implementation KCSMetadata
@synthesize lastModifiedTime;
@synthesize acl;

- (id) initWithKMD:(NSDictionary*)kmd acl:(NSDictionary*)pACL
{
    self = [super init];
    if (self) {
        NSString* lmt = [kmd objectForKey:kKMDLMTKey];
        lastModifiedTime = [[NSDate dateFromISO8601EncodedString:lmt] retain];
        acl = [[NSMutableDictionary dictionaryWithDictionary:pACL] retain];
    }
    return self;
}

- (NSString*) creatorId 
{
    return [acl objectForKey:kACLCreatorKey];
}

- (BOOL) hasWritePermission
{
    KCSUser* user = [[KCSClient sharedClient] currentUser];
    NSString* userId = [user userId];
    return [[self creatorId] isEqualToString:userId] || [[self usersWithWriteAccess] containsObject:userId] || [self isGloballyWritable];
}

- (NSArray*) usersWithReadAccess
{
    NSArray* readers = [acl objectForKey:kACLReadersKey];
    return readers == nil ? [NSArray array] : readers;
}

- (void) setUsersWithReadAccess:(NSArray*) readers
{
    [acl setObject:readers forKey:kACLReadersKey];
}

- (NSArray*) usersWithWriteAccess
{
    NSArray* readers = [acl objectForKey:kACLWritersKey];
    return readers == nil ? [NSArray array] : readers;
}

- (void) setUsersWithWriteAccess:(NSArray*) readers
{
    [acl setObject:readers forKey:kACLWritersKey];
}

- (BOOL) isGloballyReadable
{
    return [[acl objectForKey:kACLGlobalReadKey] boolValue];
}

- (void) setGloballyReadable:(BOOL)readable
{
    [acl setObject:[NSNumber numberWithBool:readable] forKey:kACLGlobalReadKey];
}

- (BOOL) isGloballyWritable
{
    return [[acl objectForKey:kACLGlobalWriteKey] boolValue];
}

- (void) setGloballyWritable:(BOOL)writable
{
    [acl setObject:[NSNumber numberWithBool:writable] forKey:kACLGlobalWriteKey];
}

- (NSDictionary*) aclValue
{
    return acl;
}

@end
