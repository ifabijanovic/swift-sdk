//
//  KCSRealmEntityPersistence.m
//  KinveyKit
//
//  Created by Victor Barros on 2015-11-23.
//  Copyright © 2015 Kinvey. All rights reserved.
//

#import "KCSRealmEntityPersistence.h"

#import <objc/runtime.h>
#import <objc/message.h>

#import <Realm/Realm.h>
#import <Foundation/Foundation.h>
#import <MapKit/MapKit.h>
#import <UIKit/UIKit.h>

#import "KinveyCoreInternal.h"
#import "KinveyPersistable.h"
#import "KCSClientMetadataRealm.h"
#import "KCSUserRealm.h"
#import "KCSAppdataStore.h"
#import "KCSHiddenMethods.h"
#import "KCSDataModel.h"
#import "KCSAclRealm.h"
#import "KCSFileRealm.h"
#import "KCS_CLLocation_Realm.h"
#import "KCS_CLLocation_Realm_ValueTransformer.h"

#import "KCS_NSArray_CLLocation_NSValueTransformer.h"
#import "KCS_NSArray_KCS_CLLocation_Realm_NSValueTransformer.h"
#import "KCS_NSURL_NSString_NSValueTransformer.h"
#import "KCS_UIImage_NSData_NSValueTransformer.h"
#import "KCS_NSString_NSDate_NSValueTransformer.h"

#import "NSValueTransformer+Kinvey.h"
#import "KCSObjcRuntime.h"

#define KCSEntityKeyAcl @"_acl"

@interface KCSRealmEntityPersistence ()

@property (nonatomic, readonly) RLMRealmConfiguration* realmConfiguration;
@property (nonatomic, readonly) RLMRealm* realm;

@end

@implementation KCSRealmEntityPersistence

@synthesize persistenceId = _persistenceId;

static NSMutableDictionary<NSString*, NSString*>* classMapOriginalRealm = nil;
static NSMutableDictionary<NSString*, NSMutableSet<NSString*>*>* classMapRealmOriginal = nil;
static NSMutableDictionary<NSString*, NSSet<NSString*>*>* realmClassProperties = nil;
static NSMutableDictionary<NSString*, NSMutableDictionary<NSString*, NSValueTransformer*>*>* valueTransformerMap = nil;

+(void)initialize
{
    static dispatch_once_t onceToken;
    dispatch_once(&onceToken, ^{
        classMapOriginalRealm = [NSMutableDictionary dictionary];
        classMapRealmOriginal = [NSMutableDictionary dictionary];
        valueTransformerMap = [NSMutableDictionary dictionary];
        
        //Collections
        
        [self registerOriginalClass:[NSArray class]
                         realmClass:[RLMArray class]];
        
        [self registerOriginalClass:[NSMutableArray class]
                         realmClass:[RLMArray class]];
        
        [self registerOriginalClass:[NSSet class]
                         realmClass:[RLMArray class]];
        
        [self registerOriginalClass:[NSMutableSet class]
                         realmClass:[RLMArray class]];
        
        [self registerOriginalClass:[NSOrderedSet class]
                         realmClass:[RLMArray class]];
        
        [self registerOriginalClass:[NSMutableOrderedSet class]
                         realmClass:[RLMArray class]];
        
        [self registerOriginalClass:[NSDictionary class]
                         realmClass:[NSDictionary class]];
        
        [self registerOriginalClass:[NSMutableDictionary class]
                         realmClass:[NSMutableDictionary class]];
        
        //NSString
        
        [self registerOriginalClass:[NSString class]
                         realmClass:[NSString class]];
        
        [self registerOriginalClass:[NSMutableString class]
                         realmClass:[NSMutableString class]];
        
        [self registerOriginalClass:[NSURL class]
                         realmClass:[NSString class]];
        
        //NSData
        
        [self registerOriginalClass:[NSData class]
                         realmClass:[NSData class]];
        
        [self registerOriginalClass:[UIImage class]
                         realmClass:[NSData class]];
        
        //NSDate
        
        [self registerOriginalClass:[NSDate class]
                         realmClass:[NSDate class]];
        
        //NSNumber
        
        [self registerOriginalClass:[NSNumber class]
                         realmClass:[NSNumber class]];
        
        //CLLocation
        
        [self registerOriginalClass:[CLLocation class]
                         realmClass:[KCS_CLLocation_Realm class]];
        
        //Kinvey Classes
        
        [self registerOriginalClass:[KCSUser class]
                         realmClass:[KCSUserRealm class]];
        
        [self registerOriginalClass:[KCSFile class]
                         realmClass:[KCSFileRealm class]];
        
        [self registerOriginalClass:[KCSMetadata class]
                         realmClass:[KCSMetadataRealm class]];
        
        realmClassProperties = [NSMutableDictionary dictionary];
        
        [self registerRealmClassProperties:[KCSUserRealm class]];
        [self registerRealmClassProperties:[KCSFileRealm class]];
        [self registerRealmClassProperties:[KCSMetadataRealm class]];
        [self registerRealmClassProperties:[KCSAclRealm class]];
        [self registerRealmClassProperties:[KCS_CLLocation_Realm class]];
        
        [NSValueTransformer setValueTransformer:[KCS_CLLocation_Realm_ValueTransformer sharedInstance]
                                      fromClass:[CLLocation class]
                                        toClass:[KCS_CLLocation_Realm_ValueTransformer transformedValueClass]];
        
        [NSValueTransformer setValueTransformer:[KCS_NSArray_CLLocation_NSValueTransformer sharedInstance]
                                      fromClass:[NSArray class]
                                        toClass:[KCS_NSArray_CLLocation_NSValueTransformer transformedValueClass]];
        
        [NSValueTransformer setValueTransformer:[KCS_NSArray_KCS_CLLocation_Realm_NSValueTransformer sharedInstance]
                                      fromClass:[NSArray class]
                                        toClass:[KCS_NSArray_KCS_CLLocation_Realm_NSValueTransformer transformedValueClass]];
        
        [NSValueTransformer setValueTransformer:[KCS_NSURL_NSString_NSValueTransformer sharedInstance]
                                      fromClass:[NSURL class]
                                        toClass:[KCS_NSURL_NSString_NSValueTransformer transformedValueClass]];
        
        [NSValueTransformer setValueTransformer:[KCS_UIImage_NSData_NSValueTransformer sharedInstance]
                                      fromClass:[UIImage class]
                                        toClass:[KCS_UIImage_NSData_NSValueTransformer transformedValueClass]];
        
        [NSValueTransformer setValueTransformer:[KCS_NSString_NSDate_NSValueTransformer sharedInstance]
                                      fromClass:[NSString class]
                                        toClass:[KCS_NSString_NSDate_NSValueTransformer transformedValueClass]];
        
        unsigned int classesCount;
        Class* classes = objc_copyClassList(&classesCount);
        Class class = nil;
        NSSet<NSString*>* ignoreClasses = [NSSet setWithArray:@[@"NSObject", @"KCSFile", @"KCSUser", @"KCSMetadata"]];
        NSString* className = nil;
        for (unsigned int i = 0; i < classesCount; i++) {
            class = classes[i];
            className = [NSString stringWithUTF8String:class_getName(class)];
            if (!class_conformsToProtocol(class, @protocol(KCSPersistable))) continue;
            if ([ignoreClasses containsObject:className]) continue;
            if (classMapOriginalRealm[className]) continue;
            
            [self createRealmClass:class];
        }
        free(classes);
    });
}

+(void)registerValueTransformer:(NSValueTransformer*)valueTransformer
                       forClass:(Class)class
                   propertyName:(NSString*)propertyName
{
    [self registerValueTransformer:valueTransformer
                      forClassName:NSStringFromClass(class)
                      propertyName:propertyName];
}

+(void)registerValueTransformer:(NSValueTransformer*)valueTransformer
                   forClassName:(NSString*)className
                   propertyName:(NSString*)propertyName
{
    NSMutableDictionary<NSString*, NSValueTransformer*>* propertyMap = valueTransformerMap[className];
    if (!propertyMap) {
        propertyMap = [NSMutableDictionary dictionary];
        valueTransformerMap[className] = propertyMap;
    }
    propertyMap[propertyName] = valueTransformer;
}

+(void)registerOriginalClass:(Class)originalClass
                  realmClass:(Class)realmClass
{
    [self registerOriginalClassName:NSStringFromClass(originalClass)
                     realmClassName:NSStringFromClass(realmClass)];
}

+(void)registerOriginalClassName:(NSString*)originalClassName
                  realmClassName:(NSString*)realmClassName
{
    classMapOriginalRealm[originalClassName] = realmClassName;
    NSMutableSet<NSString*>* originalClassNames = classMapRealmOriginal[realmClassName];
    if (!originalClassNames) originalClassNames = [NSMutableSet setWithCapacity:1];
    [originalClassNames addObject:originalClassName];
    classMapRealmOriginal[realmClassName] = originalClassNames;
}

-(instancetype)initWithPersistenceId:(NSString *)key
{
    self = [super init];
    if (self) {
        _persistenceId = key;
    }
    return self;
}

-(RLMRealmConfiguration *)realmConfiguration
{
    static RLMRealmConfiguration* configuration = nil;
    static dispatch_once_t onceToken;
    dispatch_once(&onceToken, ^{
        configuration = [RLMRealmConfiguration defaultConfiguration];
        
        NSMutableArray<NSString*>* pathComponents = [configuration.path pathComponents].mutableCopy;
        pathComponents[pathComponents.count - 1] = [NSString stringWithFormat:@"com.kinvey.%@_cache.realm", self.persistenceId];
        configuration.path = [NSString pathWithComponents:pathComponents];
    });
    return configuration;
}

-(RLMRealm *)realm
{
    NSError* error = nil;
    RLMRealm* realm = [RLMRealm realmWithConfiguration:self.realmConfiguration
                                                 error:&error];
    if (error) {
        @throw error;
    }
    return realm;
}

+(Class)createRealmClass:(Class)class
{
    NSString* className = [NSString stringWithUTF8String:class_getName(class)];
    
    NSString* realmClassName = [NSString stringWithFormat:@"%@_KinveyRealm", className];
    Class realmClass = objc_allocateClassPair([RLMObject class], realmClassName.UTF8String, 0);
    
    if (classMapOriginalRealm[className]) return NSClassFromString(classMapOriginalRealm[className]);
    
    [self registerOriginalClass:class
                     realmClass:realmClass];
    
    [self copyPropertiesFromClass:class
                          toClass:realmClass];
    
    objc_registerClassPair(realmClass);
    
    [self registerRealmClassProperties:realmClass];
    
    [self createPrimaryKeyMethodFromClass:class
                                  toClass:realmClass];
    
    return realmClass;
}

+(void)registerRealmClassProperties:(Class)realmClass
{
    realmClassProperties[NSStringFromClass(realmClass)] = [KCSObjcRuntime propertyNamesForClass:realmClass];
}

+(void)copyPropertiesFromClass:(Class)fromClass
                       toClass:(Class)toClass
{
    unsigned int propertyCount;
    objc_property_t *properties = class_copyPropertyList(fromClass, &propertyCount);
    NSSet<NSString*>* ignoreClasses = [NSSet setWithArray:@[@"NSDictionary", @"NSMutableDictionary", @"NSAttributedString", @"NSMutableAttributedString"]];
    NSSet<NSString*>* subtypeRequiredClasses = [NSSet setWithArray:@[@"NSArray", @"NSMutableArray", @"NSSet", @"NSMutableSet", @"NSOrderedSet", @"NSMutableOrderedSet", @"NSNumber"]];
    NSRegularExpression* regexClassName = [NSRegularExpression regularExpressionWithPattern:@"@\"(\\w+)(?:<(\\w+)>)?\""
                                                                                    options:0
                                                                                      error:nil];
    NSArray<NSTextCheckingResult*>* matches = nil;
    NSTextCheckingResult* textCheckingResult = nil;
    NSValueTransformer* valueTransformer = nil;
    NSRange range;
    NSString *attributeValue = nil, *propertyName = nil, *className = nil, *subtypeName = nil, *realmClassName = nil;
    objc_property_t property;
    unsigned int attributeCount;
    objc_property_attribute_t *attributes = nil;
    objc_property_attribute_t attribute;
    BOOL ignoreProperty;
    for (int i = 0; i < propertyCount; i++) {
        property = properties[i];
        propertyName = [NSString stringWithUTF8String:property_getName(property)];
        attributeCount = 0;
        attributes = property_copyAttributeList(property, &attributeCount);
        ignoreProperty = NO;
        className = nil;
        for (unsigned int i = 0; i < attributeCount; i++) {
            attribute = attributes[i];
            switch (attribute.name[0]) {
                case 'T':
                    switch (attribute.value[0]) {
                        case 'c':
                            break;
                        case 'i':
                            break;
                        case 's':
                            break;
                        case 'l':
                            break;
                        case 'q':
                            break;
                        case 'C':
                            break;
                        case 'I':
                            break;
                        case 'S':
                            break;
                        case 'L':
                            break;
                        case 'Q': { //unsigned long long
                            ignoreProperty = YES;
                            KCSLogWarn(KCS_LOG_CONTEXT_DATA, @"Data type not supported: [%@ %@]", NSStringFromClass(fromClass), propertyName);
                            break;
                        }
                        case 'f':
                            break;
                        case 'd':
                            break;
                        case 'B':
                            break;
                        case '@':
                            attributeValue = [NSString stringWithUTF8String:attribute.value];
                            matches = [regexClassName matchesInString:attributeValue
                                                              options:0
                                                                range:NSMakeRange(0, attributeValue.length)];
                            if (matches.count > 0 &&
                                matches.firstObject.numberOfRanges > 1 &&
                                [matches.firstObject rangeAtIndex:1].location != NSNotFound)
                            {
                                textCheckingResult = matches.firstObject;
                                className = [attributeValue substringWithRange:[textCheckingResult rangeAtIndex:1]];
                                range = [textCheckingResult rangeAtIndex:2];
                                subtypeName = range.location != NSNotFound ? [attributeValue substringWithRange:range] : nil;
                                if ([ignoreClasses containsObject:className]) {
                                    ignoreProperty = YES;
                                    KCSLogWarn(KCS_LOG_CONTEXT_DATA, @"Data type not supported: [%@ %@] (%@)", NSStringFromClass(fromClass), propertyName, className);
                                } else if ([subtypeRequiredClasses containsObject:className] &&
                                           subtypeName == nil)
                                {
                                    ignoreProperty = YES;
                                    KCSLogWarn(KCS_LOG_CONTEXT_DATA, @"Data type requires a subtype: [%@ %@] (%@)", NSStringFromClass(fromClass), propertyName, className);
                                } else {
                                    realmClassName = classMapOriginalRealm[className];
                                    if ([className isEqualToString:realmClassName]) {
                                        valueTransformer = nil;
                                    } else {
                                        valueTransformer = [NSValueTransformer valueTransformerFromClassName:className
                                                                                                 toClassName:realmClassName];
                                    }
                                    if (valueTransformer) {
                                        [self registerValueTransformer:valueTransformer
                                                              forClass:fromClass
                                                          propertyName:propertyName];
                                    } else if (classMapOriginalRealm[className] == nil) {
                                        realmClassName = NSStringFromClass([self createRealmClass:NSClassFromString(className)]);
                                    }
                                    if (realmClassName) {
                                        if (subtypeName) {
                                            attribute.value = [NSString stringWithFormat:@"@\"%@<%@>\"", realmClassName, classMapOriginalRealm[subtypeName] ? classMapOriginalRealm[subtypeName] : subtypeName].UTF8String;
                                        } else {
                                            attribute.value = [NSString stringWithFormat:@"@\"%@\"", realmClassName].UTF8String;
                                            if ([realmClassName isEqualToString:NSStringFromClass([KCSMetadataRealm class])])
                                            {
                                                [self createAclToClass:toClass];
                                            }
                                        }
                                        attributes[i] = attribute;
                                    }
                                }
                            }
                            break;
                        default:
                            break;
                    }
                    break;
                case 'R':
                    ignoreProperty = YES;
                    break;
                default:
                    break;
            }
        }
        if (!ignoreProperty) {
            BOOL added = class_addProperty(toClass, propertyName.UTF8String, attributes, attributeCount);
            assert(added);
        }
        free(attributes);
    }
    free(properties);
}

+(void)createAclToClass:(Class)toClass
{
    objc_property_attribute_t type = { "T", [NSString stringWithFormat:@"@\"%@\"", NSStringFromClass([KCSAclRealm  class])].UTF8String };
    objc_property_attribute_t ownership = { "C", "" }; // C = copy
    objc_property_attribute_t backingivar  = { "V", [NSString stringWithFormat:@"_%@", KCSEntityKeyAcl].UTF8String };
    objc_property_attribute_t attrs[] = { type, ownership, backingivar };
    BOOL added = class_addProperty(toClass, KCSEntityKeyAcl.UTF8String, attrs, 3);
    assert(added);
}

+(void)createPrimaryKeyMethodFromClass:(Class)fromClass
                               toClass:(Class)toClass
{
    NSString* primaryKey = nil;
    @try {
        id<KCSPersistable> sampleObj = [[fromClass alloc] init];
        NSDictionary* propertyMapping = [sampleObj hostToKinveyPropertyMapping];
        NSString* value;
        for (NSString* key in propertyMapping) {
            value = propertyMapping[key];
            if ([value isEqualToString:KCSEntityKeyId]) {
                primaryKey = key;
                break;
            }
        }
    } @catch (NSException *exception) {
        //do nothing!
    }
    
    if (!primaryKey) {
        primaryKey = KCSEntityKeyId;
        objc_property_attribute_t type = { "T", "@\"NSString\"" };
        objc_property_attribute_t ownership = { "C", "" }; // C = copy
        objc_property_attribute_t backingivar  = { "V", [NSString stringWithFormat:@"_%@", primaryKey].UTF8String };
        objc_property_attribute_t attrs[] = { type, ownership, backingivar };
        BOOL added = class_addProperty(toClass, primaryKey.UTF8String, attrs, 3);
        if (!added) {
            class_replaceProperty(toClass, primaryKey.UTF8String, attrs, 3);
        }
    }
    
    SEL sel = @selector(primaryKey);
    IMP imp = imp_implementationWithBlock(^NSString*(Class class) {
        return primaryKey;
    });
    Method method = class_getClassMethod(toClass, sel);
    const char* className = class_getName(toClass);
    Class metaClass = objc_getMetaClass(className);
    BOOL added = class_addMethod(metaClass, sel, imp, method_getTypeEncoding(method));
    assert(added);
}

-(NSDictionary *)clientMetadata
{
    RLMRealm* realm = self.realm;
    NSDictionary* clientMetadata = nil;
    KCSClientMetadataRealm* metadata = [KCSClientMetadataRealm allObjectsInRealm:realm].lastObject;
    if (metadata) {
        clientMetadata = @{ @"appkey" : metadata.appkey };
    }
    return clientMetadata;
}

-(BOOL)setClientMetadata:(NSDictionary *)metadata
{
    RLMRealm* realm = self.realm;
    [realm transactionWithBlock:^{
        [realm deleteObjects:[KCSClientMetadataRealm allObjectsInRealm:realm]];
        [KCSClientMetadataRealm createOrUpdateInRealm:realm
                                            withValue:metadata];
    }];
    return YES;
}

-(BOOL)updateObject:(id<KCSPersistable>)object
             entity:(NSDictionary *)entity
              route:(NSString *)route
         collection:(NSString *)collection
{
    BOOL (*updateEntity)(id, SEL, id<KCSPersistable>, NSDictionary*, NSString*, NSString*) = (BOOL (*)(id, SEL, id<KCSPersistable>, NSDictionary*, NSString*, NSString*)) objc_msgSend;
    return updateEntity(self, NSSelectorFromString([NSString stringWithFormat:@"updateObject:entity:%@Route:collection:", route]), object, entity, route, collection);
}

-(BOOL)updateObject:(id<KCSPersistable>)object
             entity:(NSDictionary*)entity
          userRoute:(NSString*)route
         collection:(NSString*)collection
{
    __block BOOL result = NO;
    RLMRealm* realm = self.realm;
    [realm transactionWithBlock:^{
        KCSUserRealm* user = [KCSUserRealm createOrUpdateInRealm:realm
                                                       withValue:entity];
        result = user != nil;
    }];
    return result;
}

+(NSMutableDictionary<NSString*, NSObject*>*)createEntity:(NSDictionary<NSString*, NSObject*>*)entity
                                               withObject:(NSObject<KCSPersistable>*)object
                                            forRealmClass:(Class)realmClass
{
    if (!entity) return nil;
    KCSDataModel* dataModel = [KCSAppdataStore caches].dataModel;
    NSDictionary<NSString*, NSString*>* propertyMapping = [object hostToKinveyPropertyMapping].invert;
    NSMutableDictionary<NSString*, NSObject*>* newEntity = [NSMutableDictionary dictionaryWithCapacity:entity.count];
    [entity enumerateKeysAndObjectsUsingBlock:^(NSString * _Nonnull key, NSObject * _Nonnull obj, BOOL * _Nonnull stop) {
        NSString* keyMap = propertyMapping[key];
        if (keyMap) {
            id value = entity[key];
            Class valueClass = [value class];
            NSString* type = [KCSObjcRuntime typeForProperty:keyMap
                                                     inClass:realmClass];
            NSValueTransformer* valueTransformer = [NSValueTransformer valueTransformerFromClass:valueClass
                                                                                         toClass:NSClassFromString(type)];
            if (valueTransformer) {
                value = [valueTransformer transformedValue:value];
            }
            if ([value isKindOfClass:[RLMObject class]]) {
                value = [value dictionaryWithValuesForKeys:realmClassProperties[type].allObjects];
            } else if ([value isKindOfClass:[CLLocation class]]) {
                CLLocation* location = value;
                value = @{ @"latitude" : @(location.coordinate.latitude),
                           @"longitude" : @(location.coordinate.longitude) };
            }
            NSString* collection = [dataModel collectionForClass:valueClass];
            if (collection) {
                NSDictionary* entity = [dataModel jsonEntityForObject:value
                                                                route:@"appdata"
                                                           collection:collection];
                newEntity[keyMap] = [self createEntity:entity
                                            withObject:value
                                         forRealmClass:valueClass];
            } else {
                newEntity[keyMap] = value;
            }
        } else if ([key isEqualToString:KCSEntityKeyAcl]) {
            NSString* metadataPropertyName = propertyMapping[KCSEntityKeyMetadata];
            KCSMetadata* metadata = metadataPropertyName ? [object valueForKey:metadataPropertyName] : nil;
            if (metadata) {
                newEntity[KCSEntityKeyAcl] = @{ @"creator" : metadata.creatorId };
            }
        }
    }];
    return newEntity;
}

-(BOOL)updateObject:(id<KCSPersistable>)object
             entity:(NSDictionary*)entity
       appdataRoute:(NSString*)route
         collection:(NSString*)collection
{
    __block BOOL result = NO;
    Class class = [[KCSAppdataStore caches].dataModel classForCollection:collection];
    NSString* realmClassName = classMapOriginalRealm[NSStringFromClass(class)];
    Class realmClass = NSClassFromString(realmClassName);
    NSMutableDictionary<NSString*, NSObject*>* newEntity = [KCSRealmEntityPersistence createEntity:entity
                                                                                        withObject:object
                                                                                     forRealmClass:realmClass];
    
    RLMRealm* realm = self.realm;
    [realm transactionWithBlock:^{
        id realmObj = [realmClass createOrUpdateInRealm:realm
                                              withValue:newEntity];
        result = realmObj != nil;
    }];
    return result;
}

-(NSArray<NSObject<KCSPersistable>*> *)entitiesForQuery:(KCSQuery2 *)query
                                                  route:(NSString *)route
                                             collection:(NSString *)collection
{
    Class class = [[KCSAppdataStore caches].dataModel classForCollection:collection];
    NSString* realmClassName = classMapOriginalRealm[NSStringFromClass(class)];
    Class realmClass = NSClassFromString(realmClassName);
    RLMRealm* realm = self.realm;
    RLMResults* results = [realmClass objectsInRealm:realm
                                       withPredicate:query.query.predicate];
    NSMutableArray<NSObject<KCSPersistable>*>* array = [NSMutableArray arrayWithCapacity:results.count];
    for (RLMObject* realmObj in results) {
        [array addObject:[self dictionaryFromRealmObject:realmObj]];
    }
    return array;
}

-(NSObject<KCSPersistable>*)dictionaryFromRealmObject:(RLMObject*)realmObj
{
    NSString* realmClassName = [[realmObj class] className];
    NSString* originalClassName = classMapRealmOriginal[realmClassName].anyObject;
    NSObject<KCSPersistable>* obj = [[NSClassFromString(originalClassName) alloc] init];
    NSValueTransformer* valueTransformer = nil;
    id value = nil;
    for (NSString* propertyName in realmClassProperties[realmClassName]) {
        if ([propertyName isEqualToString:KCSEntityKeyAcl]) continue;
        value = [realmObj valueForKey:propertyName];
        valueTransformer = valueTransformerMap[originalClassName][propertyName];
        if (valueTransformer) {
            value = [valueTransformer reverseTransformedValue:value];
        } else if ([value isKindOfClass:[RLMObject class]]) {
            value = [self dictionaryFromRealmObject:value];
        }
        [obj setValue:value
               forKey:propertyName];
    }
    return obj;
}

-(BOOL)removeEntity:(NSString *)_id route:(NSString *)route collection:(NSString *)collection
{
    return NO;
}

-(NSArray *)idsForQuery:(KCSQuery2 *)query
                  route:(NSString *)route
             collection:(NSString *)collection
{
    return nil;
}

-(NSDictionary *)entityForId:(NSString *)_id route:(NSString *)route collection:(NSString *)collection
{
    return nil;
}

-(BOOL)setIds:(NSArray *)theseIds forQuery:(NSString *)query route:(NSString *)route collection:(NSString *)collection
{
    return YES;
}

-(BOOL)removeQuery:(NSString *)query route:(NSString *)route collection:(NSString *)collection
{
    return NO;
}

-(void)clearCaches
{
    RLMRealm* realm = self.realm;
    [realm transactionWithBlock:^{
        [realm deleteAllObjects];
    }];
}

@end