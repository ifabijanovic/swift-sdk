//
//  Entity.swift
//  Kinvey
//
//  Created by Victor Barros on 2016-06-14.
//  Copyright © 2016 Kinvey. All rights reserved.
//

import Foundation
import Realm
import RealmSwift
import ObjectMapper

/// Key to map the `_id` column in your Persistable implementation class.
@available(*, deprecated: 3.5.2, message: "Please use Entity.Key.entityId instead")
public let PersistableIdKey = "_id"

/// Key to map the `_acl` column in your Persistable implementation class.
@available(*, deprecated: 3.5.2, message: "Please use Entity.Key.acl instead")
public let PersistableAclKey = "_acl"

/// Key to map the `_kmd` column in your Persistable implementation class.
@available(*, deprecated: 3.5.2, message: "Please use Entity.Key.metadata instead")
public let PersistableMetadataKey = "_kmd"

public typealias List<T: RealmSwift.Object> = RealmSwift.List<T>
public typealias Object = RealmSwift.Object

internal func StringFromClass(cls: AnyClass) -> String {
    var className = NSStringFromClass(cls)
    let regex = try! NSRegularExpression(pattern: "(?:RLM.+_(.+))|(?:RLM:\\S* (.*))") // regex to catch Realm classnames like `RLMStandalone_`, `RLMUnmanaged_`, `RLMAccessor_` or `RLM:Unmanaged `
    var nMatches = regex.numberOfMatches(in: className, range: NSRange(location: 0, length: className.characters.count))
    while nMatches > 0 {
        let classObj: AnyClass! = NSClassFromString(className)!
        let superClass: AnyClass! = class_getSuperclass(classObj)
        className = NSStringFromClass(superClass)
        nMatches = regex.numberOfMatches(in: className, range: NSRange(location: 0, length: className.characters.count))
    }
    return className
}

/// Base class for entity classes that are mapped to a collection in Kinvey.
open class Entity: Object, Persistable {
    
    public struct Key {
        
        /// Key to map the `_id` column in your Persistable implementation class.
        public static let entityId = "_id"
        
        /// Key to map the `_acl` column in your Persistable implementation class.
        public static let acl = "_acl"
        
        /// Key to map the `_kmd` column in your Persistable implementation class.
        public static let metadata = "_kmd"
        
    }
    
    /// This function can be used to validate JSON prior to mapping. Return nil to cancel mapping at this point
    public required init?(map: Map) {
        super.init()
    }
    
    /// Override this method and return the name of the collection for Kinvey.
    open class func collectionName() -> String {
        fatalError("Method \(#function) must be overridden")
    }
    
    open class func newInstance() -> Self {
        return self.init()
    }
    
    /// The `_id` property mapped in the Kinvey backend.
    public dynamic var entityId: String?
    
    /// The `_kmd` property mapped in the Kinvey backend.
    public dynamic var metadata: Metadata?
    
    /// The `_acl` property mapped in the Kinvey backend.
    public dynamic var acl: Acl?
    
    /// Default Constructor.
    public required init() {
        super.init()
    }
    
    /**
     WARNING: This is an internal initializer not intended for public use.
     :nodoc:
     */
    public required init(realm: RLMRealm, schema: RLMObjectSchema) {
        super.init(realm: realm, schema: schema)
    }
    
    /**
     WARNING: This is an internal initializer not intended for public use.
     :nodoc:
     */
    public required init(value: Any, schema: RLMSchema) {
        super.init(value: value, schema: schema)
    }
    
    /// Override this method to tell how to map your own objects.
    open func propertyMapping(_ map: Map) {
        entityId <- ("entityId", map[Key.entityId])
        metadata <- ("metadata", map[Key.metadata])
        acl <- ("acl", map[Key.acl])
    }
    
    /**
     WARNING: This is an internal initializer not intended for public use.
     :nodoc:
     */
    open override class func primaryKey() -> String? {
        return entityIdProperty()
    }
    
    /**
     WARNING: This is an internal initializer not intended for public use.
     :nodoc:
     */
    open override class func ignoredProperties() -> [String] {
        var properties = [String]()
        for (propertyName, (type, subType)) in ObjCRuntime.properties(forClass: self) {
            if let type = type,
                let typeClass = NSClassFromString(type),
                !(ObjCRuntime.type(typeClass, isSubtypeOf: NSDate.self) ||
                ObjCRuntime.type(typeClass, isSubtypeOf: NSData.self) ||
                ObjCRuntime.type(typeClass, isSubtypeOf: NSString.self) ||
                ObjCRuntime.type(typeClass, isSubtypeOf: RLMObjectBase.self) ||
                ObjCRuntime.type(typeClass, isSubtypeOf: RLMOptionalBase.self) ||
                ObjCRuntime.type(typeClass, isSubtypeOf: RLMListBase.self) ||
                ObjCRuntime.type(typeClass, isSubtypeOf: RLMCollection.self))
            {
                properties.append(propertyName)
            } else if let subType = subType,
                let _ = NSProtocolFromString(subType)
            {
                properties.append(propertyName)
            }
        }
        return properties
    }
    
    /// This function is where all variable mappings should occur. It is executed by Mapper during the mapping (serialization and deserialization) process.
    public func mapping(map: Map) {
        let originalThread = Thread.current
        let runningMapping = originalThread.threadDictionary[KinveyMappingTypeKey] != nil
        if runningMapping {
            let operationQueue = OperationQueue()
            operationQueue.name = "Kinvey Property Mapping"
            operationQueue.maxConcurrentOperationCount = 1
            operationQueue.addOperation {
                let className = StringFromClass(cls: type(of: self))
                Thread.current.threadDictionary[KinveyMappingTypeKey] = [className : PropertyMap()]
                self.propertyMapping(map)
                originalThread.threadDictionary[KinveyMappingTypeKey] = Thread.current.threadDictionary[KinveyMappingTypeKey]
            }
            operationQueue.waitUntilAllOperationsAreFinished()
        } else {
            self.propertyMapping(map)
        }
    }
    
}

open class StringValue: Object, ExpressibleByStringLiteral {
    
    public dynamic var value = ""
    
    public convenience required init(unicodeScalarLiteral value: String) {
        self.init()
        self.value = value
    }
    
    public convenience required init(extendedGraphemeClusterLiteral value: String) {
        self.init()
        self.value = value
    }
    
    public convenience required init(stringLiteral value: String) {
        self.init()
        self.value = value
    }
    
    public convenience init(_ value: String) {
        self.init()
        self.value = value
    }
    
}

open class IntValue: Object, ExpressibleByIntegerLiteral {
    
    public dynamic var value = 0
    
    public convenience required init(integerLiteral value: Int) {
        self.init()
        self.value = value
    }
    
    public convenience init(_ value: Int) {
        self.init()
        self.value = value
    }
    
}

open class FloatValue: Object, ExpressibleByFloatLiteral {
    
    public dynamic var value = Float(0)
    
    public convenience required init(floatLiteral value: Float) {
        self.init()
        self.value = value
    }
    
    public convenience init(_ value: Float) {
        self.init()
        self.value = value
    }
    
}

open class DoubleValue: Object, ExpressibleByFloatLiteral {
    
    public dynamic var value = 0.0
    
    public convenience required init(floatLiteral value: Double) {
        self.init()
        self.value = value
    }
    
    public convenience init(_ value: Double) {
        self.init()
        self.value = value
    }
    
}

open class BoolValue: Object, ExpressibleByBooleanLiteral {
    
    public dynamic var value = false
    
    public convenience required init(booleanLiteral value: Bool) {
        self.init()
        self.value = value
    }
    
    public convenience init(_ value: Bool) {
        self.init()
        self.value = value
    }
    
}
