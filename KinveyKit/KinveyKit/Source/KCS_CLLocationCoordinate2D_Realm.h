//
//  KCSCLLocationCoordinate2DRealm.h
//  KinveyKit
//
//  Created by Victor Barros on 2015-11-25.
//  Copyright © 2015 Kinvey. All rights reserved.
//

#import <Realm/Realm.h>

@interface KCS_CLLocationCoordinate2D_Realm : RLMObject

@property double latitude;
@property double longitude;

@end
