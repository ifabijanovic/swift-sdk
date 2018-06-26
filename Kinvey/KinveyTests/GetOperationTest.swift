//
//  GetOperationTest.swift
//  Kinvey
//
//  Created by Victor Barros on 2016-02-15.
//  Copyright © 2016 Kinvey. All rights reserved.
//

import XCTest
@testable import Kinvey

class GetOperationTest: StoreTestCase {
    
    override func tearDown() {
        super.tearDown()
        store.ttl = nil
    }
    
    override func save() -> Person {
        let person = self.person
        
        weak var expectationSave = expectation(description: "Save")
        
        store.save(person, options: Options(writePolicy: .forceNetwork)) { (person, error) -> Void in
            XCTAssertNotNil(person)
            XCTAssertNil(error)
            
            if let person = person {
                XCTAssertEqual(person, self.person)
                XCTAssertNotNil(person.personId)
            }
            
            expectationSave?.fulfill()
        }
        
        waitForExpectations(timeout: defaultTimeout) { error in
            expectationSave = nil
        }
        
        return person
    }
    
    func testForceNetwork() {
        let person = save()
        
        XCTAssertNotNil(person.personId)
        if let personId = person.personId {
            weak var expectationGet = expectation(description: "Get")
            
            store.find(personId, readPolicy: .ForceNetwork) { (person, error) -> Void in
                XCTAssertNotNil(person)
                XCTAssertNil(error)
                
                expectationGet?.fulfill()
            }
            
            waitForExpectations(timeout: defaultTimeout) { error in
                expectationGet = nil
            }
        }
    }
    
    func testForceLocal() {
        let person = save()
        
        XCTAssertNotNil(person.personId)
        if let personId = person.personId {
            weak var expectationGet = expectation(description: "Get")
            
            store.find(personId, readPolicy: .forceLocal) { (person, error) -> Void in
                XCTAssertNotNil(person)
                XCTAssertNil(error)
                
                expectationGet?.fulfill()
            }
            
            waitForExpectations(timeout: defaultTimeout) { error in
                expectationGet = nil
            }
        }
    }
    
    func testForceLocalExpiredTTL() {
        let person = save()
        
        store.ttl = 1.seconds
        
        NSThread.sleepForTimeInterval(1)
        
        XCTAssertNotNil(person.personId)
        if let personId = person.personId {
            weak var expectationGet = expectation(description: "Get")
            
            store.findById(personId, readPolicy: .ForceLocal) { (person, error) -> Void in
                XCTAssertNil(person)
                XCTAssertNil(error)
                
                expectationGet?.fulfill()
            }
            
            waitForExpectations(timeout: defaultTimeout) { error in
                expectationGet = nil
            }
        }
    }
    
    func testBoth() {
        weak var expectationSaveLocal = expectation(description: "SaveLocal")
        weak var expectationSaveNetwork = expectation(description: "SaveNetwork")
        
        var isLocal = true
        
        store.save(person, writePolicy: .LocalThenNetwork) { (person, error) -> Void in
            XCTAssertNotNil(person)
            XCTAssertNil(error)
            
            if let person = person {
                XCTAssertEqual(person, self.person)
                XCTAssertNotNil(person.personId)
            }
            
            if isLocal {
                expectationSaveLocal?.fulfill()
                isLocal = false
            } else {
                expectationSaveNetwork?.fulfill()
            }
        }
        
        waitForExpectations(timeout: defaultTimeout) { error in
            expectationSaveLocal = nil
            expectationSaveNetwork = nil
        }
        
        XCTAssertNotNil(person.personId)
        if let personId = person.personId {
            weak var expectationGetLocal = expectation(description: "GetLocal")
            weak var expectationGetNetwork = expectation(description: "GetNetwork")
            
            var isLocal = true
            
            store.find(personId, readPolicy: .Both) { (person, error) -> Void in
                XCTAssertNotNil(person)
                XCTAssertNil(error)
                
                if isLocal {
                    expectationGetLocal?.fulfill()
                    isLocal = false
                } else {
                    expectationGetNetwork?.fulfill()
                }
            }
            
            waitForExpectations(timeout: defaultTimeout) { error in
                expectationGetLocal = nil
                expectationGetNetwork = nil
            }
        }
    }
    
}
