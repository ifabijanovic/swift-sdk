//
//  KCSAddress.h
//  KinveyKit
//
//  Created by Victor Barros on 2015-11-23.
//  Copyright © 2015 Kinvey. All rights reserved.
//

#import <Foundation/Foundation.h>
#import <MapKit/MapKit.h>

@interface KCSAddress : NSObject

@property NSString* city;
@property NSString* province;
@property NSString* country;
@property CLLocation* location;

@end