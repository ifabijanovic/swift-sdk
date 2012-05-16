//
//  NSArray+KinveyAdditions.m
//  KinveyKit
//
//  Created by Michael Katz on 5/11/12.
//  Copyright (c) 2012 Kinvey. All rights reserved.
//

#import "NSArray+KinveyAdditions.h"

@implementation NSArray (KinveyAdditions)

+ (NSArray*) wrapIfNotArray:(id)object
{
    // If we're given a class that is not an array, then we need to wrap the object
    // as an array so we do a single unified processing
    if ([object isKindOfClass:[NSArray class]]){
        return object;
    } else {
        return [NSArray arrayWithObject:object];
    }
}

@end
