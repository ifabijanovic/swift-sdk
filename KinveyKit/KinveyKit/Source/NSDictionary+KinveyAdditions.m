//
//  NSDictionary+KinveyAdditions.m
//  KinveyKit
//
//  Created by Michael Katz on 3/14/13.
//  Copyright (c) 2013-2015 Kinvey. All rights reserved.
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


#import "NSDictionary+KinveyAdditions.h"
#import "KinveyCoreInternal.h"
#import "KCSMutableOrderedDictionary.h"

@implementation NSMutableDictionary (KinveyAdditionsMutable)

-(instancetype)invert
{
    return [super invert];
}

@end

@implementation NSDictionary (KinveyAdditions)

- (instancetype) stripKeys:(NSArray*)keys
{
    NSMutableDictionary* copy = [self mutableCopy];
    for (NSString* key in keys) {
        if (copy[key]) {
            copy[key] = @"XXXXXXXXX";
        }
    }
    return copy;
}

- (instancetype) dictionaryByAddingDictionary:(NSDictionary*)dictionary
{
    NSMutableDictionary* md = [self mutableCopy];
    [md addEntriesFromDictionary:dictionary];
    return md;
}

- (NSString*) escapedJSON
{
    NSString* jsonStr = [self kcsJSONRepresentation];
    return [NSString stringByPercentEncodingString:jsonStr];
}

-(NSString *)jsonString
{
    NSError *error = nil;
    NSData *data = [NSJSONSerialization dataWithJSONObject:[KCSMutableOrderedDictionary dictionaryWithDictionary:self]
                                                   options:0
                                                     error:&error];
    
    if (error) {
        [[NSException exceptionWithName:error.domain
                                 reason:error.localizedDescription ? error.localizedDescription : error.description
                               userInfo:error.userInfo] raise];
    }
    
    if (data) {
        return [[NSString alloc] initWithData:data
                                     encoding:NSUTF8StringEncoding];
    }
    
    return nil;
}

-(instancetype)invert
{
    NSMutableDictionary* d = [NSMutableDictionary dictionaryWithCapacity:self.count];
    [self enumerateKeysAndObjectsUsingBlock:^(id key, id obj, BOOL *stop) {
        if ([obj isKindOfClass:[NSString class]]) {
            d[obj] = key;
        }
    }];
    return d;
}

-(NSString *)queryString
{
    NSMutableString* result = [NSMutableString string];
    for (NSString* key in self.allKeys) {
        [result appendFormat:@"%@=%@&", [NSString stringByPercentEncodingString:key], [NSString stringByPercentEncodingString:self[key]]];
    }
    if (result.length > 0) {
        [result deleteCharactersInRange:NSMakeRange(result.length - 1, 1)];
    }
    return result;
}

-(NSString *)kcsJSONRepresentation
{
    NSData* data = [NSJSONSerialization dataWithJSONObject:self
                                                   options:0
                                                     error:nil];
    if (data) {
        return [[NSString alloc] initWithData:data
                                     encoding:NSUTF8StringEncoding];
    }
    return nil;
}

@end
