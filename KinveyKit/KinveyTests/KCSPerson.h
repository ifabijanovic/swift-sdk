//
//  KCSPerson.h
//  KinveyKit
//
//  Created by Victor Barros on 2015-11-23.
//  Copyright © 2015 Kinvey. All rights reserved.
//

#import <Foundation/Foundation.h>
#import <KinveyKit/KinveyKit.h>
#import "KCSAddress.h"
#import "KCSCompany.h"

@interface KCSPerson : NSObject <KCSPersistable>

@property NSString* personId;
@property NSString* name;
@property NSInteger age;
@property UIImage* picture;
@property KCSAddress* address;
@property KCSCompany* company;
@property NSDate* dateOfBirth;
@property KCSMetadata* metadata;

@end
