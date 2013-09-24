//
//  KCSFileOperation.h
//  KinveyKit
//
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


#import <Foundation/Foundation.h>

/* A progress block.
 @param objects if there are any valid objects available. Could be `nil` or empty.
 @param percentComplete the percentage of the total progress made so far. Suitable for a progress indicator.
 */
KK2(cleanup and merge)
typedef void(^KCSProgressBlock2)(NSArray *objects, double percentComplete, NSDictionary* additionalContext);


typedef void (^StreamCompletionBlock)(BOOL done, NSDictionary* returnInfo, NSError* error);


@protocol KCSFileOperation <NSObject>

@end