//
//  Cache.swift
//  Kinvey
//
//  Created by Victor Barros on 2016-01-20.
//  Copyright © 2016 Kinvey. All rights reserved.
//

import Foundation

internal protocol CacheType {
    
    var persistenceId: String { get }
    var collectionName: String { get }
    var ttl: NSTimeInterval? { get set }
    
    associatedtype Type
    
    func saveEntity(entity: Type)
    
    func saveEntities(entities: [Type])
    
    func findEntity(objectId: String) -> Type?
    
    func findEntityByQuery(query: Query) -> [Type]
    
    func findIdsLmtsByQuery(query: Query) -> [String : String]
    
    func findAll() -> [Type]
    
    func count(query: Query?) -> UInt
    
    func removeEntity(entity: Type) -> Bool
    
    func removeEntities(entity: [Type]) -> Bool
    
    func removeEntitiesByQuery(query: Query) -> UInt
    
    func removeAllEntities()
    
}

extension CacheType {
    
    func isEmpty() -> Bool {
        return count(nil) == 0
    }
    
}

internal class Cache<T: Persistable where T: NSObject>: CacheType {
    
    internal typealias Type = T
    
    let persistenceId: String
    let collectionName: String
    var ttl: NSTimeInterval?
    
    init(persistenceId: String, ttl: NSTimeInterval? = nil) {
        self.persistenceId = persistenceId
        self.collectionName = T.collectionName()
        self.ttl = ttl
    }
    
    func detach(entity: T) -> T {
        preconditionFailure("Method \(#function) must be overridden")
    }
    
    func detach(entity: [T]) -> [T] {
        preconditionFailure("Method \(#function) must be overridden")
    }
    
    func saveEntity(entity: T) {
        preconditionFailure("Method \(#function) must be overridden")
    }
    
    func saveEntities(entities: [T]) {
        preconditionFailure("Method \(#function) must be overridden")
    }
    
    func findEntity(objectId: String) -> T? {
        preconditionFailure("Method \(#function) must be overridden")
    }
    
    func findEntityByQuery(query: Query) -> [T] {
        preconditionFailure("Method \(#function) must be overridden")
    }
    
    func findIdsLmtsByQuery(query: Query) -> [String : String] {
        preconditionFailure("Method \(#function) must be overridden")
    }
    
    func findAll() -> [T] {
        preconditionFailure("Method \(#function) must be overridden")
    }
    
    func count(query: Query? = nil) -> UInt {
        preconditionFailure("Method \(#function) must be overridden")
    }
    
    func removeEntity(entity: T) -> Bool {
        preconditionFailure("Method \(#function) must be overridden")
    }
    
    func removeEntities(entity: [T]) -> Bool {
        preconditionFailure("Method \(#function) must be overridden")
    }
    
    func removeEntitiesByQuery(query: Query) -> UInt {
        preconditionFailure("Method \(#function) must be overridden")
    }
    
    func removeAllEntities() {
        preconditionFailure("Method \(#function) must be overridden")
    }
    
}
