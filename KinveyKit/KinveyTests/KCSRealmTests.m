//
//  KCSRealmTests.m
//  KinveyKit
//
//  Created by Victor Barros on 2015-11-23.
//  Copyright © 2015 Kinvey. All rights reserved.
//

#import "KCSTestCase.h"
#import <KinveyKit/KinveyKit.h>

#import "KCSPerson.h"

@interface KCSRealmTests : KCSTestCase

@property (nonatomic, strong) KCSCollection* collectionPerson;
@property (nonatomic, strong) id<KCSStore> storePerson;

@property (nonatomic, strong) KCSCollection* collectionCompany;
@property (nonatomic, strong) id<KCSStore> storeCompany;

@property (nonatomic, readonly) KCSPerson* person;
@property (nonatomic, readonly) UIImage* personPicture;
@property (nonatomic, readonly) KCSAddress* address;
@property (nonatomic, readonly) KCSCompany* company;

@end

@implementation KCSRealmTests

- (void)setUp {
    [super setUp];
    
    [self setupKCS];
    [self createAutogeneratedUser];
    
    self.collectionPerson = [KCSCollection collectionFromString:@"Person"
                                                        ofClass:[KCSPerson class]];
    self.storePerson = [KCSLinkedAppdataStore storeWithCollection:self.collectionPerson
                                                          options:@{ KCSStoreKeyCachePolicy : @(KCSCachePolicyLocalFirst) }];
    
    self.collectionCompany = [KCSCollection collectionFromString:@"Company"
                                                         ofClass:[KCSCompany class]];
    self.storeCompany = [KCSLinkedAppdataStore storeWithCollection:self.collectionCompany
                                                           options:@{ KCSStoreKeyCachePolicy : @(KCSCachePolicyLocalFirst) }];
}

- (void)tearDown {
    [self removeAndLogoutActiveUser:30];
    
    [super tearDown];
}

-(KCSCompany *)company
{
    KCSCompany* company = [[KCSCompany alloc] init];
    company.name = @"Kinvey";
    company.url = [NSURL URLWithString:@"http://www.kinvey.com"];
    company.location = [[CLLocation alloc] initWithLatitude:42.3536711
                                                  longitude:-71.0587098];
    return company;
}

-(KCSAddress *)address
{
    KCSAddress* address = [[KCSAddress alloc] init];
    address.city = @"Vancouver";
    address.province = @"BC";
    address.country = @"Canada";
    address.location = [[CLLocation alloc] initWithLatitude:49.2827
                                                  longitude:-123.1207];
    return address;
}

-(KCSPerson *)person
{
    KCSPerson* person = [[KCSPerson alloc] init];
    person.name = @"Victor";
    person.age = 29;
    person.address = self.address;
    person.company = self.company;
    person.picture = self.personPicture;
    NSDateFormatter* dateFormatter = [[NSDateFormatter alloc] init];
    dateFormatter.dateFormat = @"yyyy-MM-dd HH:mm:ss zzz";
    person.dateOfBirth = [dateFormatter dateFromString:@"1986-03-07 04:32:07 UTC"];
    return person;
}

-(UIImage *)personPicture
{
    static UIImage* image;
    static dispatch_once_t onceToken;
    dispatch_once(&onceToken, ^{
        image = [UIImage imageNamed:@"Profile Picture"
                           inBundle:[NSBundle bundleForClass:[self class]]
      compatibleWithTraitCollection:nil];
    });
    return image;
}

- (void)testRealmSave {
    KCSPerson* person = self.person;
    KCSCompany* company = person.company;
    
    __block __weak XCTestExpectation* expectationSaveCompany = [self expectationWithDescription:@"saveCompany"];
    
    [self.storeCompany saveObject:company
       withCompletionBlock:^(NSArray<KCSCompany*> *objectsOrNil, NSError *errorOrNil)
     {
         XCTAssertNotNil(objectsOrNil);
         XCTAssertNil(errorOrNil);
         XCTAssertEqual(objectsOrNil.count, 1);
         if (objectsOrNil.count > 0) {
             KCSCompany* _company = objectsOrNil.firstObject;
             XCTAssertEqual(company, _company);
             XCTAssertTrue([_company isKindOfClass:[KCSCompany class]]);
             XCTAssertNotNil(company.companyId);
             XCTAssertNotNil(company.metadata);
             XCTAssertEqualObjects(company.name, _company.name);
             XCTAssertEqualObjects(company.url, _company.url);
             XCTAssertEqualObjects(company.location, _company.location);
             XCTAssertTrue([_company.location isKindOfClass:[CLLocation class]]);
         }
         
         [expectationSaveCompany fulfill];
     } withProgressBlock:nil];
    
    [self waitForExpectationsWithTimeout:30
                                 handler:^(NSError * _Nullable error)
     {
         expectationSaveCompany = nil;
     }];
    
    __block __weak XCTestExpectation* expectationSavePerson = [self expectationWithDescription:@"savePerson"];
    
    [self.storePerson saveObject:person
       withCompletionBlock:^(NSArray<KCSPerson*> *objectsOrNil, NSError *errorOrNil)
    {
        XCTAssertNotNil(objectsOrNil);
        XCTAssertNil(errorOrNil);
        XCTAssertEqual(objectsOrNil.count, 1);
        if (objectsOrNil.count > 0) {
            KCSPerson* _person = objectsOrNil.firstObject;
            XCTAssertEqual(person, _person);
            XCTAssertTrue([_person isKindOfClass:[KCSPerson class]]);
            XCTAssertNotNil(person.personId);
            XCTAssertEqualObjects(person.name, _person.name);
            XCTAssertEqual(person.age, _person.age);
            XCTAssertNotNil(person.metadata);
            
            XCTAssertNotNil(_person.picture);
            XCTAssertTrue([_person.picture isKindOfClass:[UIImage class]]);
            XCTAssertEqualObjects(person.picture, _person.picture);
            
            XCTAssertNotNil(_person.dateOfBirth);
            XCTAssertTrue([_person.dateOfBirth isKindOfClass:[NSDate class]]);
            XCTAssertEqualObjects(person.dateOfBirth, _person.dateOfBirth);
            
            XCTAssertNotNil(_person.address);
            XCTAssertTrue([_person.address isKindOfClass:[KCSAddress class]]);
            if ([_person.address isKindOfClass:[KCSAddress class]]) {
                XCTAssertEqualObjects(person.address.city, _person.address.city);
                XCTAssertEqualObjects(person.address.province, _person.address.province);
                XCTAssertEqualObjects(person.address.country, _person.address.country);
                XCTAssertEqualObjects(person.address.location, _person.address.location);
                XCTAssertNotNil(_person.address.location);
                XCTAssertTrue([_person.address.location isKindOfClass:[CLLocation class]]);
            }
            
            XCTAssertNotNil(_person.company);
            XCTAssertTrue([_person.company isKindOfClass:[KCSCompany class]]);
            if ([_person.company isKindOfClass:[KCSCompany class]]) {
                XCTAssertEqualObjects(person.company.companyId, _person.company.companyId);
                XCTAssertEqualObjects(person.company.name, _person.company.name);
                XCTAssertEqualObjects(person.company.url, _person.company.url);
                XCTAssertNotNil(person.company.metadata);
                XCTAssertNotNil(_person.company.metadata);
            }
        }
        
        [expectationSavePerson fulfill];
    } withProgressBlock:nil];
    
    [self waitForExpectationsWithTimeout:30
                                 handler:^(NSError * _Nullable error)
    {
        expectationSavePerson = nil;
    }];
}

-(void)testRealmQuery {
    [self testRealmSave];
    
    KCSPerson* person = self.person;
    
    [self measureBlock:^{
        __block __weak XCTestExpectation* expectationQueryPerson = [self expectationWithDescription:@"queryPerson"];
        
        KCSQuery* query = [KCSQuery queryWithPredicate:[NSPredicate predicateWithFormat:@"name == %@ AND _acl.creator == %@", person.name, [KCSUser activeUser].userId]];
        [self.storePerson queryWithQuery:query
                     withCompletionBlock:^(NSArray<KCSPerson*> *objectsOrNil, NSError *errorOrNil)
         {
             XCTAssertNotNil(objectsOrNil);
             XCTAssertNil(errorOrNil);
             XCTAssertEqual(objectsOrNil.count, 1);
             if (objectsOrNil.count > 0) {
                 KCSPerson* _person = objectsOrNil.firstObject;
                 XCTAssertTrue([_person isKindOfClass:[KCSPerson class]]);
                 XCTAssertNotNil(_person.personId);
                 XCTAssertEqualObjects(person.name, _person.name);
                 XCTAssertEqual(person.age, _person.age);
                 XCTAssertNotNil(_person.picture);
                 XCTAssertTrue([_person.picture isKindOfClass:[UIImage class]]);
                 
                 XCTAssertNotNil(_person.dateOfBirth);
                 XCTAssertTrue([_person.dateOfBirth isKindOfClass:[NSDate class]]);
                 XCTAssertEqualObjects(person.dateOfBirth, _person.dateOfBirth);
                 
                 XCTAssertNotNil(_person.address);
                 XCTAssertTrue([_person.address isKindOfClass:[KCSAddress class]]);
                 if ([_person.address isKindOfClass:[KCSAddress class]]) {
                     XCTAssertEqualObjects(person.address.city, _person.address.city);
                     XCTAssertEqualObjects(person.address.province, _person.address.province);
                     XCTAssertEqualObjects(person.address.country, _person.address.country);
                     XCTAssertNotNil(_person.address.location);
                     XCTAssertTrue([_person.address.location isKindOfClass:[CLLocation class]]);
                 }
                 
                 XCTAssertNotNil(_person.company);
                 XCTAssertTrue([_person.company isKindOfClass:[KCSCompany class]]);
                 if ([_person.company isKindOfClass:[KCSCompany class]]) {
                     XCTAssertNotNil(_person.company.companyId);
                     XCTAssertEqualObjects(person.company.name, _person.company.name);
                     XCTAssertTrue([_person.company.url isKindOfClass:[NSURL class]]);
                     XCTAssertEqualObjects(person.company.url, _person.company.url);
                     XCTAssertNotNil(_person.company.metadata);
                     XCTAssertTrue([_person.company.location isKindOfClass:[CLLocation class]]);
                     double accuracy = 0.0000000001;
                     XCTAssertEqualWithAccuracy(person.company.location.coordinate.latitude, _person.company.location.coordinate.latitude, accuracy);
                     XCTAssertEqualWithAccuracy(person.company.location.coordinate.longitude, _person.company.location.coordinate.longitude, accuracy);
                 }
             }
             
             [expectationQueryPerson fulfill];
         } withProgressBlock:nil];
        
        [self waitForExpectationsWithTimeout:30
                                     handler:^(NSError * _Nullable error)
         {
             expectationQueryPerson = nil;
         }];
    }];
}

@end
