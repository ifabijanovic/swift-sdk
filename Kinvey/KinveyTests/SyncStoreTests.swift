//
//  SyncedStoreTests.swift
//  Kinvey
//
//  Created by Victor Barros on 2015-12-17.
//  Copyright © 2015 Kinvey. All rights reserved.
//

import XCTest
@testable import Kinvey

class SyncStoreTests: StoreTestCase {
    
    class CheckForNetworkURLProtocol: NSURLProtocol {
        
        override class func canInitWithRequest(request: NSURLRequest) -> Bool {
            XCTFail()
            return false
        }
        
    }
    
    override func setUp() {
        super.setUp()
        
        signUp()
        
        store = DataStore<Person>.getInstance(.Sync)
    }
    
    func testPurge() {
        save()
        
        weak var expectationPurge = expectationWithDescription("Purge")
        
        let query = Query(format: "_acl.creatorId == %@", client.activeUser!.userId)
        store.purge(query) { (count, error) -> Void in
            XCTAssertNotNil(count)
            XCTAssertNil(error)
            
            expectationPurge?.fulfill()
        }
        
        waitForExpectationsWithTimeout(defaultTimeout) { error in
            expectationPurge = nil
        }
    }
    
    func testPurgeInvalidDataStoreType() {
        save()
        
        store = DataStore<Person>.getInstance()
        
        weak var expectationPurge = expectationWithDescription("Purge")
        
        let query = Query(format: "_acl.creatorId == %@", client.activeUser!.userId)
        store.purge(query) { (count, error) -> Void in
            self.assertThread()
            XCTAssertNil(count)
            XCTAssertNotNil(error)
            
            if let error = error as? NSError {
                XCTAssertEqual(error, Error.InvalidDataStoreType.error)
            }
            
            expectationPurge?.fulfill()
        }
        
        waitForExpectationsWithTimeout(defaultTimeout) { error in
            expectationPurge = nil
        }
    }
    
    func testPurgeTimeoutError() {
        let person = save()
        person.age = person.age + 1
        save(person)
        
        setURLProtocol(TimeoutErrorURLProtocol.self)
        defer {
            setURLProtocol(nil)
        }
        
        weak var expectationPurge = expectationWithDescription("Purge")
        
        let query = Query(format: "_acl.creatorId == %@", client.activeUser!.userId)
        store.purge(query) { (count, error) -> Void in
            XCTAssertNil(count)
            XCTAssertNotNil(error)
            
            expectationPurge?.fulfill()
        }
        
        waitForExpectationsWithTimeout(defaultTimeout) { error in
            expectationPurge = nil
        }
    }
    
    func testSync() {
        save()
        
        weak var expectationSync = expectationWithDescription("Sync")
        
        store.sync() { count, results, error in
            self.assertThread()
            XCTAssertNotNil(count)
            XCTAssertNotNil(results)
            XCTAssertNil(error)
            
            if let count = count {
                XCTAssertGreaterThanOrEqual(Int(count), 1)
            }
            
            expectationSync?.fulfill()
        }
        
        waitForExpectationsWithTimeout(defaultTimeout) { error in
            expectationSync = nil
        }
    }
    
    func testSyncInvalidDataStoreType() {
        save()
        
        store = DataStore<Person>.getInstance()
        
        weak var expectationSync = expectationWithDescription("Sync")
        
        store.sync() { count, results, error in
            self.assertThread()
            XCTAssertNil(count)
            XCTAssertNotNil(error)
            
            if let error = error as? NSError {
                XCTAssertEqual(error, Error.InvalidDataStoreType.error)
            }
            
            expectationSync?.fulfill()
        }
        
        waitForExpectationsWithTimeout(defaultTimeout) { error in
            expectationSync = nil
        }
    }
    
    func testSyncTimeoutError() {
        save()
        
        setURLProtocol(TimeoutErrorURLProtocol.self)
        defer {
            setURLProtocol(nil)
        }
        
        weak var expectationSync = expectationWithDescription("Sync")
        
        store.sync() { count, results, error in
            self.assertThread()
            XCTAssertNil(count)
            XCTAssertNil(results)
            XCTAssertNotNil(error)
            
            expectationSync?.fulfill()
        }
        
        waitForExpectationsWithTimeout(defaultTimeout) { error in
            expectationSync = nil
        }
    }
    
    func testSyncNoCompletionHandler() {
        save()
        
        let request = store.sync()
        
        weak var expectationExecuting = keyValueObservingExpectationForObject(request, keyPath: "executing", expectedValue: false)
        
        XCTAssertNotNil(expectationExecuting)
        
        waitForExpectationsWithTimeout(defaultTimeout) { error in
            expectationExecuting = nil
        }
    }
    
    func testPush() {
        save()
        
        weak var expectationPush = expectationWithDescription("Push")
        
        store.push() { count, error in
            self.assertThread()
            XCTAssertNotNil(count)
            XCTAssertNil(error)
            
            if let count = count {
                XCTAssertGreaterThanOrEqual(Int(count), 1)
            }
            
            expectationPush?.fulfill()
        }
        
        waitForExpectationsWithTimeout(defaultTimeout) { error in
            expectationPush = nil
        }
    }
    
    func testPushInvalidDataStoreType() {
        save()
        
        store = DataStore<Person>.getInstance()
        
        weak var expectationPush = expectationWithDescription("Push")
        
        store.push() { count, error in
            self.assertThread()
            XCTAssertNil(count)
            XCTAssertNotNil(error)
            
            if let error = error as? NSError {
                XCTAssertEqual(error, Error.InvalidDataStoreType.error)
            }
            
            expectationPush?.fulfill()
        }
        
        waitForExpectationsWithTimeout(defaultTimeout) { error in
            expectationPush = nil
        }
    }
    
    func testPushNoCompletionHandler() {
        save()
        
        let request = store.push()
        
        weak var expectationExecuting = keyValueObservingExpectationForObject(request, keyPath: "executing", expectedValue: false)
        
        XCTAssertNotNil(expectationExecuting)
        
        waitForExpectationsWithTimeout(defaultTimeout) { error in
            expectationExecuting = nil
        }
    }
    
    func testPull() {
        save()
        
        weak var expectationPull = expectationWithDescription("Pull")
        
        store.pull() { results, error in
            self.assertThread()
            XCTAssertNotNil(results)
            XCTAssertNil(error)
            
            if let results = results {
                XCTAssertGreaterThanOrEqual(results.count, 1)
            }
            
            expectationPull?.fulfill()
        }
        
        waitForExpectationsWithTimeout(defaultTimeout) { error in
            expectationPull = nil
        }
    }
    
    func testPullInvalidDataStoreType() {
        save()
        
        store = DataStore<Person>.getInstance()
        
        weak var expectationPull = expectationWithDescription("Pull")
        
        store.pull() { results, error in
            self.assertThread()
            XCTAssertNil(results)
            XCTAssertNotNil(error)
            
            if let error = error as? NSError {
                XCTAssertEqual(error, Error.InvalidDataStoreType.error)
            }
            
            expectationPull?.fulfill()
        }
        
        waitForExpectationsWithTimeout(defaultTimeout) { error in
            expectationPull = nil
        }
    }
    
    func testFindById() {
        let person = save()
        
        XCTAssertNotNil(person.personId)
        
        guard let personId = person.personId else { return }
        
        setURLProtocol(CheckForNetworkURLProtocol.self)
        defer {
            setURLProtocol(nil)
        }
        
        weak var expectationFind = expectationWithDescription("Find")
        
        store.find(personId) { result, error in
            self.assertThread()
            XCTAssertNotNil(result)
            XCTAssertNil(error)
            
            if let result = result {
                XCTAssertEqual(result.personId, personId)
            }
            
            expectationFind?.fulfill()
        }
        
        waitForExpectationsWithTimeout(defaultTimeout) { error in
            expectationFind = nil
        }
    }
    
    func testFindByQuery() {
        let person = save()
        
        XCTAssertNotNil(person.personId)
        
        guard let personId = person.personId else { return }
        
        setURLProtocol(CheckForNetworkURLProtocol.self)
        defer {
            setURLProtocol(nil)
        }
        
        let query = Query(format: "personId == %@", personId)
        
        weak var expectationFind = expectationWithDescription("Find")
        
        store.find(query) { results, error in
            self.assertThread()
            XCTAssertNotNil(results)
            XCTAssertNil(error)
            
            if let results = results {
                XCTAssertNotNil(results.first)
                if let result = results.first {
                    XCTAssertEqual(result.personId, personId)
                }
            }
            
            expectationFind?.fulfill()
        }
        
        waitForExpectationsWithTimeout(defaultTimeout) { error in
            expectationFind = nil
        }
    }
    
    func testRemovePersistable() {
        let person = save()
        
        XCTAssertNotNil(person.personId)
        
        setURLProtocol(CheckForNetworkURLProtocol.self)
        defer {
            setURLProtocol(nil)
        }
        
        weak var expectationRemove = expectationWithDescription("Remove")
        
        do {
            try store.remove(person) { count, error in
                self.assertThread()
                XCTAssertNotNil(count)
                XCTAssertNil(error)
                
                if let count = count {
                    XCTAssertEqual(count, 1)
                }
                
                expectationRemove?.fulfill()
            }
        } catch {
            XCTFail()
            expectationRemove?.fulfill()
        }
            
        waitForExpectationsWithTimeout(defaultTimeout) { error in
            expectationRemove = nil
        }
    }
    
    func testRemovePersistableIdMissing() {
        let person = save()
        
        XCTAssertNotNil(person.personId)
        
        setURLProtocol(CheckForNetworkURLProtocol.self)
        defer {
            setURLProtocol(nil)
        }
        
        weak var expectationRemove = expectationWithDescription("Remove")
        
        do {
            person.personId = nil
            try store.remove(person) { count, error in
                XCTFail()
                
                expectationRemove?.fulfill()
            }
            XCTFail()
        } catch {
            expectationRemove?.fulfill()
        }
        
        waitForExpectationsWithTimeout(defaultTimeout) { error in
            expectationRemove = nil
        }
    }
    
    func testRemovePersistableArray() {
        let person1 = save(newPerson)
        let person2 = save(newPerson)
        
        XCTAssertNotNil(person1.personId)
        XCTAssertNotNil(person2.personId)
        
        guard let personId1 = person1.personId, let personId2 = person2.personId else { return }
        
        XCTAssertNotEqual(personId1, personId2)
        
        setURLProtocol(CheckForNetworkURLProtocol.self)
        defer {
            setURLProtocol(nil)
        }
        
        weak var expectationRemove = expectationWithDescription("Remove")
        
        store.remove([person1, person2]) { count, error in
            self.assertThread()
            XCTAssertNotNil(count)
            XCTAssertNil(error)
            
            if let count = count {
                XCTAssertEqual(count, 2)
            }
            
            expectationRemove?.fulfill()
        }
        
        waitForExpectationsWithTimeout(defaultTimeout) { error in
            expectationRemove = nil
        }
    }
    
    func testRemoveAll() {
        let person1 = save(newPerson)
        let person2 = save(newPerson)
        
        XCTAssertNotNil(person1.personId)
        XCTAssertNotNil(person2.personId)
        
        guard let personId1 = person1.personId, let personId2 = person2.personId else { return }
        
        XCTAssertNotEqual(personId1, personId2)
        
        setURLProtocol(CheckForNetworkURLProtocol.self)
        defer {
            setURLProtocol(nil)
        }
        
        weak var expectationRemove = expectationWithDescription("Remove")
        
        store.removeAll() { count, error in
            self.assertThread()
            XCTAssertNotNil(count)
            XCTAssertNil(error)
            
            if let count = count {
                XCTAssertEqual(count, 2)
            }
            
            expectationRemove?.fulfill()
        }
        
        waitForExpectationsWithTimeout(defaultTimeout) { error in
            expectationRemove = nil
        }
    }
    
    func testExpiredTTL() {
        store.ttl = 1.seconds
        
        let person = save()
        
        XCTAssertNotNil(person.personId)
        
        NSThread.sleepForTimeInterval(1)
        
        if let personId = person.personId {
            weak var expectationGet = expectationWithDescription("Get")
            
            let query = Query(format: "personId == %@", personId)
            store.find(query, readPolicy: .ForceLocal) { (persons, error) -> Void in
                XCTAssertNotNil(persons)
                XCTAssertNil(error)
                
                if let persons = persons {
                    XCTAssertEqual(persons.count, 0)
                }
                
                expectationGet?.fulfill()
            }
            
            waitForExpectationsWithTimeout(defaultTimeout) { error in
                expectationGet = nil
            }
        }
        
        store.ttl = nil
        
        if let personId = person.personId {
            weak var expectationGet = expectationWithDescription("Get")
            
            let query = Query(format: "personId == %@", personId)
            store.find(query, readPolicy: .ForceLocal) { (persons, error) -> Void in
                XCTAssertNotNil(persons)
                XCTAssertNil(error)
                
                if let persons = persons {
                    XCTAssertEqual(persons.count, 1)
                }
                
                expectationGet?.fulfill()
            }
            
            waitForExpectationsWithTimeout(defaultTimeout) { error in
                expectationGet = nil
            }
        }
    }
    
}