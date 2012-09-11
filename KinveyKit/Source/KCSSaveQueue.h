//
//  SaveQueue.h
//  KinveyKit
//
//  Copyright (c) 2012 Kinvey. All rights reserved.
//
//  This software contains valuable confidential and proprietary information of
//  KINVEY, INC and is subject to applicable licensing agreements.
//  Unauthorized reproduction, transmission or distribution of this file and its
//  contents is a violation of applicable laws.

#import <Foundation/Foundation.h>
#import "KCSBlockDefs.h"
#import "KCSOfflineSaveStore.h"

@class KCSCollection;

@interface KCSSaveQueueItem : NSObject
@property (nonatomic, retain) NSDate* mostRecentSaveDate;
@property (nonatomic, retain) id<KCSPersistable> object;
@end

@interface KCSSaveQueue : NSObject <NSCoding>
@property (nonatomic, assign) id<KCSOfflineSaveDelegate> delegate;

+ (KCSSaveQueue*) saveQueueForCollection:(KCSCollection*)collection uniqueIdentifier:(NSString*)identifier;

- (void) addObject:(id<KCSPersistable>)obj;
- (void) removeItem:(KCSSaveQueueItem*)item;
- (NSArray*) ids;
- (NSArray*) array;
- (NSUInteger) count;
@end
