//
//  NetworkStoreTests.swift
//  Kinvey
//
//  Created by Victor Barros on 2015-12-15.
//  Copyright © 2015 Kinvey. All rights reserved.
//

import XCTest
import Foundation
@testable import Kinvey
import CoreLocation
import MapKit
import Nimble

#if os(macOS)
    typealias BezierPath = NSBezierPath
#else
    typealias BezierPath = UIBezierPath
#endif

class NetworkStoreTests: StoreTestCase {
    
    override func setUp() {
        super.setUp()
        signUp()
        
        store = DataStore<Person>.collection()
    }
    
    override func assertThread() {
        XCTAssertTrue(Thread.isMainThread)
    }
    
    func testSaveEvent() {
        guard !useMockData else {
            return
        }
        
        let store = DataStore<Event>.collection(.network)
        
        let event = Event()
        event.name = "Friday Party!"
        event.publishDate = Date(timeIntervalSince1970: 1468001397) // Fri, 08 Jul 2016 18:09:57 GMT
        event.location = "The closest pub!"
        
        event.acl?.globalRead.value = true
        event.acl?.globalWrite.value = true
        
        do {
            weak var expectationCreate = expectation(description: "Create")
            
            let request = store.save(event) { event, error in
                XCTAssertNotNil(event)
                XCTAssertNil(error)
                
                if let event = event {
                    XCTAssertNotNil(event.entityId)
                    XCTAssertNotNil(event.name)
                    XCTAssertNotNil(event.publishDate)
                    XCTAssertNotNil(event.location)
                }
                
                expectationCreate?.fulfill()
            }
            
            var uploadProgressCount = 0
            var uploadProgressSent: Int64? = nil
            var uploadProgressTotal: Int64? = nil
            
            var downloadProgressCount = 0
            var downloadProgressSent: Int64? = nil
            var downloadProgressTotal: Int64? = nil
            
            request.progress = {
                XCTAssertTrue(Thread.isMainThread)
                if $0.countOfBytesSent == $0.countOfBytesExpectedToSend && $0.countOfBytesExpectedToReceive > 0 {
                    if downloadProgressCount == 0 {
                        downloadProgressSent = $0.countOfBytesReceived
                        downloadProgressTotal = $0.countOfBytesExpectedToReceive
                    } else {
                        XCTAssertEqual(downloadProgressTotal, $0.countOfBytesExpectedToReceive)
                        XCTAssertGreaterThan($0.countOfBytesReceived, downloadProgressSent!)
                        downloadProgressSent = $0.countOfBytesReceived
                    }
                    downloadProgressCount += 1
                    print("Download: \($0.countOfBytesReceived)/\($0.countOfBytesExpectedToReceive)")
                } else {
                    if uploadProgressCount == 0 {
                        uploadProgressSent = $0.countOfBytesSent
                        uploadProgressTotal = $0.countOfBytesExpectedToSend
                    } else {
                        XCTAssertEqual(uploadProgressTotal, $0.countOfBytesExpectedToSend)
                        XCTAssertGreaterThan($0.countOfBytesSent, uploadProgressSent!)
                        uploadProgressSent = $0.countOfBytesSent
                    }
                    uploadProgressCount += 1
                    print("Upload: \($0.countOfBytesSent)/\($0.countOfBytesExpectedToSend)")
                }
            }
            
            waitForExpectations(timeout: defaultTimeout) { error in
                expectationCreate = nil
            }
            
            XCTAssertGreaterThan(uploadProgressCount, 0)
            XCTAssertGreaterThan(downloadProgressCount, 0)
        }
        
        XCTAssertNotNil(event.entityId)
        
        if let eventId = event.entityId {
            weak var expectationFind = expectation(description: "Find")
            
            let request = store.find(eventId) { event, error in
                XCTAssertNotNil(event)
                XCTAssertNil(error)
                
                if let event = event {
                    XCTAssertNotNil(event.entityId)
                    XCTAssertNotNil(event.name)
                    XCTAssertNotNil(event.publishDate)
                    XCTAssertNotNil(event.location)
                }
                
                expectationFind?.fulfill()
            }
            
            waitForExpectations(timeout: defaultTimeout) { error in
                expectationFind = nil
            }
        }
        
        do {
            class DelayURLProtocol: URLProtocol {
                
                static var delay: TimeInterval?
                
                let urlSession = URLSession(configuration: URLSessionConfiguration.default)
                
                override class func canInit(with request: URLRequest) -> Bool {
                    return true
                }
                
                override class func canonicalRequest(for request: URLRequest) -> URLRequest {
                    return request
                }
                
                override func startLoading() {
                    if let delay = DelayURLProtocol.delay {
                        RunLoop.current.run(until: Date(timeIntervalSinceNow: delay))
                    }
                    
                    let dataTask = urlSession.dataTask(with: request) { data, response, error in
                        self.client?.urlProtocol(self, didReceive: response!, cacheStoragePolicy: .notAllowed)
                        if let data = data {
                            let chuckSize = Int(ceil(Double(data.count) / 10.0))
                            var offset = 0
                            while offset < data.count {
                                let chunk = data.subdata(in: offset ..< offset + min(chuckSize, data.count - offset))
                                self.client?.urlProtocol(self, didLoad: chunk)
                                if let delay = DelayURLProtocol.delay {
                                    RunLoop.current.run(until: Date(timeIntervalSinceNow: delay))
                                }
                                offset += chuckSize
                            }
                        }
                        self.client?.urlProtocolDidFinishLoading(self)
                    }
                    dataTask.resume()
                }
                
                override func stopLoading() {
                }
                
            }
            
            DelayURLProtocol.delay = 1
            
            setURLProtocol(DelayURLProtocol.self)
            defer {
                setURLProtocol(nil)
            }
            
            weak var expectationFind = expectation(description: "Find")
            
            let request = store.find() { (events, error) in
                XCTAssertTrue(Thread.isMainThread)
                XCTAssertNotNil(events)
                XCTAssertNil(error)
                
                expectationFind?.fulfill()
            }
            
            var downloadProgressCount = 0
            var downloadProgressSent: Int64? = nil
            var downloadProgressTotal: Int64? = nil
            request.progress = {
                XCTAssertTrue(Thread.isMainThread)
                if downloadProgressCount == 0 {
                    downloadProgressSent = $0.countOfBytesReceived
                    downloadProgressTotal = $0.countOfBytesExpectedToReceive
                } else {
                    XCTAssertEqual(downloadProgressTotal, $0.countOfBytesExpectedToReceive)
                    XCTAssertGreaterThan($0.countOfBytesReceived, downloadProgressSent!)
                    downloadProgressSent = $0.countOfBytesReceived
                }
                downloadProgressCount += 1
                print("Download: \($0.countOfBytesReceived)/\($0.countOfBytesExpectedToReceive)")
            }
            
            waitForExpectations(timeout: defaultTimeout) { error in
                expectationFind = nil
            }
            
            XCTAssertGreaterThan(downloadProgressCount, 0)
        }
    }
    
    func testSaveAddress() {
        if useMockData {
            mockResponse(json: [
                "name": "Victor Barros",
                "age": 0,
                "address": [
                    "city": "Vancouver"
                ],
                "_acl": [
                    "creator": "58450d87c077970e38a388ba"
                ],
                "_kmd": [
                    "lmt": "2016-12-05T06:47:35.711Z",
                    "ect": "2016-12-05T06:47:35.711Z"
                ],
                "_id": "58450d87f29e22207c83a236"
            ])
        }
        defer {
            if useMockData {
                setURLProtocol(nil)
            }
        }
        
        let person = Person()
        person.name = "Victor Barros"
        
        let address = Address()
        address.city = "Vancouver"
        
        person.address = address
        
        weak var expectationSave = expectation(description: "Save")
        
        store.save(person, writePolicy: .forceNetwork) { person, error in
            XCTAssertNotNil(person)
            XCTAssertNil(error)
            
            if let person = person {
                XCTAssertNotNil(person.address)
                
                if let address = person.address {
                    XCTAssertNotNil(address.city)
                }
            }
            
            expectationSave?.fulfill()
        }
        
        waitForExpectations(timeout: defaultTimeout) { error in
            expectationSave = nil
        }
    }
    
    func testCount() {
        let store = DataStore<Event>.collection(.network)
        
        var eventsCount: Int? = nil
        
        do {
            if useMockData {
                mockResponse(json: ["count" : 85])
            }
            defer {
                if useMockData {
                    setURLProtocol(nil)
                }
            }
            
            weak var expectationCount = expectation(description: "Count")
            
            store.count { (count, error) in
                XCTAssertNotNil(count)
                XCTAssertNil(error)
                
                XCTAssertEqual(count, 85)
                
                eventsCount = count
                
                expectationCount?.fulfill()
            }
            
            waitForExpectations(timeout: defaultTimeout) { error in
                expectationCount = nil
            }
        }
        
        do {
            weak var expectationCount = expectation(description: "Count")
            
            store.count(readPolicy: .forceLocal) { (count, error) in
                XCTAssertNotNil(count)
                XCTAssertNil(error)
                
                XCTAssertEqual(count, 0)
                
                expectationCount?.fulfill()
            }
            
            waitForExpectations(timeout: defaultTimeout) { error in
                expectationCount = nil
            }
        }
        
        XCTAssertNotNil(eventsCount)
        
        do {
            if useMockData {
                mockResponse(statusCode: 201, json: [
                    "name": "Friday Party!",
                    "_acl": [
                        "creator": "58450c8000a5907e7dfb37bf"
                    ],
                    "_kmd": [
                        "lmt": "2016-12-05T06:43:12.395Z",
                        "ect": "2016-12-05T06:43:12.395Z"
                    ],
                    "_id": "58450c80d5ee86507a8b4e7e"
                ])
            }
            defer {
                if useMockData {
                    setURLProtocol(nil)
                }
            }
            
            let event = Event()
            event.name = "Friday Party!"
            
            weak var expectationCreate = expectation(description: "Create")
            
            store.save(event) { event, error in
                XCTAssertNotNil(event)
                XCTAssertNil(error)
                
                expectationCreate?.fulfill()
            }
            
            waitForExpectations(timeout: defaultTimeout) { error in
                expectationCreate = nil
            }
        }
        
        do {
            if useMockData {
                mockResponse(json: ["count" : 86])
            }
            defer {
                if useMockData {
                    setURLProtocol(nil)
                }
            }
            
            weak var expectationCount = expectation(description: "Count")
            
            store.count { (count, error) in
                XCTAssertNotNil(count)
                XCTAssertNil(error)
                
                if let eventsCount = eventsCount, let count = count {
                    XCTAssertEqual(eventsCount + 1, count)
                }
                
                expectationCount?.fulfill()
            }
            
            waitForExpectations(timeout: defaultTimeout) { error in
                expectationCount = nil
            }
        }
    }
    
    func testCountTranslateQuery() {
        let store = DataStore<Event>.collection(.network)
        
        if useMockData {
            mockResponse { (request) -> HttpResponse in
                let urlComponents = URLComponents(url: request.url!, resolvingAgainstBaseURL: false)!
                let queryString = urlComponents.queryItems!.filter { $0.name == "query" }.first!.value!
                let query = try! JSONSerialization.jsonObject(with: queryString.data(using: .utf8)!) as! JsonDictionary
                XCTAssertNil(query["publishDate"])
                XCTAssertNotNil(query["date"])
                return HttpResponse(json: ["count" : 85])
            }
        }
        defer {
            if useMockData {
                setURLProtocol(nil)
            }
        }
        
        weak var expectationCount = expectation(description: "Count")
        
        let query = Query(format: "publishDate >= %@", Date())
        
        store.count(query) { (count, error) in
            XCTAssertNotNil(count)
            XCTAssertNil(error)
            
            XCTAssertEqual(count, 85)
            
            expectationCount?.fulfill()
        }
        
        waitForExpectations(timeout: defaultTimeout) { error in
            expectationCount = nil
        }
    }
    
    func testCountTimeoutError() {
        let store = DataStore<Event>.collection(.network)
        
        mockResponse(error: timeoutError)
        defer {
            setURLProtocol(nil)
        }
        
        weak var expectationCount = expectation(description: "Count")
        
        store.count { (count, error) in
            XCTAssertNil(count)
            XCTAssertNotNil(error)
            
            XCTAssertTimeoutError(error)
            
            expectationCount?.fulfill()
        }
        
        waitForExpectations(timeout: defaultTimeout) { error in
            expectationCount = nil
        }
    }
    
    func testSaveAndFind10SkipLimit() {
        XCTAssertNotNil(Kinvey.sharedClient.activeUser)
        
        guard let user = Kinvey.sharedClient.activeUser else {
            return
        }
        
        var i = 0
        
        var mockData = [JsonDictionary]()
        do {
            if useMockData {
                mockResponse { request in
                    var json = try! JSONSerialization.jsonObject(with: request) as! JsonDictionary
                    json["_acl"] = [
                        "creator": self.client.activeUser?.userId
                    ]
                    json["_kmd"] = [
                        "lmt": Date().toString(),
                        "ect": Date().toString()
                    ]
                    json["_id"] = UUID().uuidString
                    mockData.append(json)
                    return HttpResponse(statusCode: 201, json: json)
                }
            }
            defer {
                if useMockData {
                    setURLProtocol(nil)
                }
            }
            
            measure {
                let person = Person {
                    $0.name = "Person \(i)"
                }
                
                weak var expectationSave = self.expectation(description: "Save")
                
                self.store.save(person, writePolicy: .forceNetwork) { person, error in
                    XCTAssertNotNil(person)
                    XCTAssertNil(error)
                    
                    expectationSave?.fulfill()
                }
                
                self.waitForExpectations(timeout: self.defaultTimeout) { error in
                    expectationSave = nil
                }
                
                i += 1
            }
        }
        
        var skip = 0
        let limit = 2
        
        if useMockData {
            mockResponse { request in
                let regex = try! NSRegularExpression(pattern: "([^&=]*)=([^&]*)")
                let query = request.url!.query!
                let matches = regex.matches(in: query, range: NSRange(location: 0, length: query.characters.count))
                var skip: Int?
                var limit: Int?
                for match in matches {
                    let key = query[query.index(query.startIndex, offsetBy: match.range(at: 1).location) ..< query.index(query.startIndex, offsetBy: match.range(at: 1).location + match.range(at: 1).length)]
                    let value = query[query.index(query.startIndex, offsetBy: match.range(at: 2).location) ..< query.index(query.startIndex, offsetBy: match.range(at: 2).location + match.range(at: 2).length)]
                    switch key {
                    case "skip":
                        skip = Int(value)
                    case "limit":
                        limit = Int(value)
                    default:
                        break
                    }
                }
                var results = mockData.sorted(by: { ($0["name"] as! String) < ($1["name"] as! String) })
                results = [JsonDictionary](results[skip! ..< skip! + limit!])
                return HttpResponse(statusCode: 200, json: results)
            }
        }
        defer {
            if useMockData {
                setURLProtocol(nil)
            }
        }
        
        for _ in 0 ..< 5 {
            weak var expectationFind = expectation(description: "Find")
            
            let query = Query {
                $0.predicate = NSPredicate(format: "acl.creator == %@", user.userId)
                $0.skip = skip
                $0.limit = limit
                $0.ascending("name")
            }
            
            store.find(query, readPolicy: .forceNetwork) { results, error in
                XCTAssertNotNil(results)
                XCTAssertNil(error)
                
                if let results = results {
                    XCTAssertEqual(results.count, limit)
                    
                    XCTAssertNotNil(results.first)
                    
                    if let person = results.first {
                        XCTAssertEqual(person.name, "Person \(skip)")
                    }
                    
                    XCTAssertNotNil(results.last)
                    
                    if let person = results.last {
                        XCTAssertEqual(person.name, "Person \(skip + 1)")
                    }
                }
                
                skip += limit
                
                expectationFind?.fulfill()
            }
            
            waitForExpectations(timeout: defaultTimeout) { error in
                expectationFind = nil
            }
        }
    }
    
    class MethodNotAllowedError: URLProtocol {
        
        static let debugValue = "insert' method is not allowed for this collection."
        static let descriptionValue = "The method is not allowed for this resource."
        
        override class func canInit(with request: URLRequest) -> Bool {
            return true
        }
        
        override class func canonicalRequest(for request: URLRequest) -> URLRequest {
            return request
        }
        
        override func startLoading() {
            let response = HTTPURLResponse(url: request.url!, statusCode: 405, httpVersion: "1.1", headerFields: [:])!
            client!.urlProtocol(self, didReceive: response, cacheStoragePolicy: .notAllowed)
            
            let responseBody = [
                "error": "MethodNotAllowed",
                "debug": MethodNotAllowedError.debugValue,
                "description": MethodNotAllowedError.descriptionValue
            ]
            let responseBodyData = try! JSONSerialization.data(withJSONObject: responseBody)
            client!.urlProtocol(self, didLoad: responseBodyData)
            
            client!.urlProtocolDidFinishLoading(self)
        }
        
        override func stopLoading() {
        }
        
    }
    
    class DataLinkEntityNotFoundError: URLProtocol {
        
        override class func canInit(with request: URLRequest) -> Bool {
            return true
        }
        
        override class func canonicalRequest(for request: URLRequest) -> URLRequest {
            return request
        }
        
        override func startLoading() {
            let response = HTTPURLResponse(url: request.url!, statusCode: 404, httpVersion: "1.1", headerFields: [:])!
            client!.urlProtocol(self, didReceive: response, cacheStoragePolicy: .notAllowed)
            
            let responseBody = [
                "error": "DataLinkEntityNotFound",
                "debug": "Error: Not Found",
                "description": "The data link could not find this entity"
            ]
            let responseBodyData = try! JSONSerialization.data(withJSONObject: responseBody)
            client!.urlProtocol(self, didLoad: responseBodyData)
            
            client!.urlProtocolDidFinishLoading(self)
        }
        
        override func stopLoading() {
        }
        
    }
    
    func testGetDataLinkEntityNotFound() {
        setURLProtocol(DataLinkEntityNotFoundError.self)
        defer {
            setURLProtocol(nil)
        }
        
        weak var expectationFind = expectation(description: "Find")
        
        store.find("sample-id", readPolicy: .forceNetwork) { person, error in
            XCTAssertNil(person)
            XCTAssertNotNil(error)
            XCTAssertTrue(error is Kinvey.Error)
            
            if let error = error as? Kinvey.Error {
                switch error {
                case .dataLinkEntityNotFound(_, _, let debug, let description):
                    XCTAssertEqual(debug, "Error: Not Found")
                    XCTAssertEqual(description, "The data link could not find this entity")
                default:
                    XCTFail()
                }
            }
            
            expectationFind?.fulfill()
        }
        
        waitForExpectations(timeout: defaultTimeout) { error in
            expectationFind = nil
        }
    }
    
    func testSaveMethodNotAllowed() {
        setURLProtocol(MethodNotAllowedError.self)
        defer {
            setURLProtocol(nil)
        }
        
        let person = Person()
        person.name = "Victor Barros"
        
        weak var expectationSave = expectation(description: "Save")
        
        store.save(person, writePolicy: .forceNetwork) { person, error in
            XCTAssertNil(person)
            XCTAssertNotNil(error)
            XCTAssertTrue(error is Kinvey.Error)
            
            if let error = error as? Kinvey.Error {
                XCTAssertEqual(error.description, MethodNotAllowedError.descriptionValue)
                XCTAssertEqual(error.debugDescription, MethodNotAllowedError.debugValue)
                
                XCTAssertEqual("\(error)", MethodNotAllowedError.descriptionValue)
                XCTAssertEqual("\(String(describing: error))", MethodNotAllowedError.descriptionValue)
                XCTAssertEqual("\(String(reflecting: error))", MethodNotAllowedError.debugValue)
                
                switch error {
                case .methodNotAllowed(_, _, let debug, let description):
                    XCTAssertEqual(description, MethodNotAllowedError.descriptionValue)
                    XCTAssertEqual(debug, MethodNotAllowedError.debugValue)
                default:
                    XCTFail()
                }
            }
            
            expectationSave?.fulfill()
        }
        
        waitForExpectations(timeout: defaultTimeout) { error in
            expectationSave = nil
        }
    }
    
    func testFindMethodNotAllowed() {
        setURLProtocol(MethodNotAllowedError.self)
        defer {
            setURLProtocol(nil)
        }
        
        weak var expectationFind = expectation(description: "Find")
        
        store.find(readPolicy: .forceNetwork) { person, error in
            XCTAssertNil(person)
            XCTAssertNotNil(error)
            XCTAssertTrue(error is Kinvey.Error)
            
            if let error = error as? Kinvey.Error {
                switch error {
                case .methodNotAllowed(_, _, let debug, let description):
                    XCTAssertEqual(debug, "insert' method is not allowed for this collection.")
                    XCTAssertEqual(description, "The method is not allowed for this resource.")
                default:
                    XCTFail()
                }
            }
            
            expectationFind?.fulfill()
        }
        
        waitForExpectations(timeout: defaultTimeout) { error in
            expectationFind = nil
        }
    }
    
    func testGetMethodNotAllowed() {
        setURLProtocol(MethodNotAllowedError.self)
        defer {
            setURLProtocol(nil)
        }
        
        weak var expectationFind = expectation(description: "Find")
        
        store.find("sample-id", readPolicy: .forceNetwork) { person, error in
            XCTAssertNil(person)
            XCTAssertNotNil(error)
            XCTAssertTrue(error is Kinvey.Error)
            
            if let error = error as? Kinvey.Error {
                switch error {
                case .methodNotAllowed(_, _, let debug, let description):
                    XCTAssertEqual(debug, "insert' method is not allowed for this collection.")
                    XCTAssertEqual(description, "The method is not allowed for this resource.")
                default:
                    XCTFail()
                }
            }
            
            expectationFind?.fulfill()
        }
        
        waitForExpectations(timeout: defaultTimeout) { error in
            expectationFind = nil
        }
    }
    
    func testRemoveByIdMethodNotAllowed() {
        setURLProtocol(MethodNotAllowedError.self)
        defer {
            setURLProtocol(nil)
        }
        
        weak var expectationRemove = expectation(description: "Remove")
        
        store.removeById("sample-id", writePolicy: .forceNetwork) { person, error in
            XCTAssertNil(person)
            XCTAssertNotNil(error)
            XCTAssertTrue(error is Kinvey.Error)
            
            if let error = error as? Kinvey.Error {
                switch error {
                case .methodNotAllowed(_, _, let debug, let description):
                    XCTAssertEqual(debug, "insert' method is not allowed for this collection.")
                    XCTAssertEqual(description, "The method is not allowed for this resource.")
                default:
                    XCTFail()
                }
            }
            
            expectationRemove?.fulfill()
        }
        
        waitForExpectations(timeout: defaultTimeout) { error in
            expectationRemove = nil
        }
    }
    
    func testRemoveMethodNotAllowed() {
        setURLProtocol(MethodNotAllowedError.self)
        defer {
            setURLProtocol(nil)
        }
        
        weak var expectationRemove = expectation(description: "Remove")
        
        store.remove(writePolicy: .forceNetwork) { count, error in
            XCTAssertNil(count)
            XCTAssertNotNil(error)
            XCTAssertTrue(error is Kinvey.Error)
            
            if let error = error as? Kinvey.Error {
                switch error {
                case .methodNotAllowed(_, _, let debug, let description):
                    XCTAssertEqual(debug, "insert' method is not allowed for this collection.")
                    XCTAssertEqual(description, "The method is not allowed for this resource.")
                default:
                    XCTFail()
                }
            }
            
            expectationRemove?.fulfill()
        }
        
        waitForExpectations(timeout: defaultTimeout) { error in
            expectationRemove = nil
        }
    }
    
    func testRemoveArrayTimeoutError() {
        let mockObjs: [[String : Any]] = [
            [
                "_id": UUID().uuidString,
                "name": "Test 1",
                "age": 18,
                "_acl": [
                    "creator": UUID().uuidString
                ],
                "_kmd": [
                    "lmt": Date().toString(),
                    "ect": Date().toString()
                ]
            ],
            [
                "_id": UUID().uuidString,
                "name": "Test 2",
                "age": 21,
                "_acl": [
                    "creator": UUID().uuidString
                ],
                "_kmd": [
                    "lmt": Date().toString(),
                    "ect": Date().toString()
                ]
            ]
        ]
        
        var _persons: [Person]? = nil
        
        do {
            mockResponse(json: mockObjs)
            defer {
                setURLProtocol(nil)
            }
            
            weak var expectationFind = expectation(description: "Find")
            
            store.find(readPolicy: .forceNetwork) { (persons, error) in
                XCTAssertNotNil(persons)
                XCTAssertNil(error)
                
                XCTAssertEqual(persons?.count, 2)
                
                _persons = persons
                
                expectationFind?.fulfill()
            }
            
            waitForExpectations(timeout: defaultTimeout, handler: { (error) in
                expectationFind = nil
            })
        }
        
        XCTAssertNotNil(_persons)
        
        if let persons = _persons {
            mockResponse(error: timeoutError)
            defer {
                setURLProtocol(nil)
            }
            
            weak var expectationRemove = expectation(description: "Remove")
            
            store.remove(persons, writePolicy: .forceNetwork) { count, error in
                XCTAssertNil(count)
                XCTAssertNotNil(error)
                
                XCTAssertTimeoutError(error)
                
                expectationRemove?.fulfill()
            }
            
            waitForExpectations(timeout: defaultTimeout) { error in
                expectationRemove = nil
            }
        }
    }
    
    func testRemoveArrayById() {
        let mockObjs: [[String : Any]] = [
            [
                "_id": UUID().uuidString,
                "name": "Test 1",
                "age": 18,
                "_acl": [
                    "creator": UUID().uuidString
                ],
                "_kmd": [
                    "lmt": Date().toString(),
                    "ect": Date().toString()
                ]
            ],
            [
                "_id": UUID().uuidString,
                "name": "Test 2",
                "age": 21,
                "_acl": [
                    "creator": UUID().uuidString
                ],
                "_kmd": [
                    "lmt": Date().toString(),
                    "ect": Date().toString()
                ]
            ]
        ]
        
        var _persons: [Person]? = nil
        
        do {
            mockResponse(json: mockObjs)
            defer {
                setURLProtocol(nil)
            }
            
            weak var expectationFind = expectation(description: "Find")
            
            store.find(readPolicy: .forceNetwork) { (persons, error) in
                XCTAssertNotNil(persons)
                XCTAssertNil(error)
                
                XCTAssertEqual(persons?.count, 2)
                
                _persons = persons
                
                expectationFind?.fulfill()
            }
            
            waitForExpectations(timeout: defaultTimeout, handler: { (error) in
                expectationFind = nil
            })
        }
        
        XCTAssertNotNil(_persons)
        
        if let persons = _persons {
            mockResponse(json: ["count" : persons.count])
            defer {
                setURLProtocol(nil)
            }
            
            weak var expectationRemove = expectation(description: "Remove")
            
            store.removeById(persons.map { $0.entityId! }, writePolicy: .forceNetwork) { count, error in
                XCTAssertNotNil(count)
                XCTAssertNil(error)
                
                XCTAssertEqual(count, persons.count)
                
                expectationRemove?.fulfill()
            }
            
            waitForExpectations(timeout: defaultTimeout) { error in
                expectationRemove = nil
            }
        }
    }
    
    func testRemoveArrayByIdTimeoutError() {
        let mockObjs: [[String : Any]] = [
            [
                "_id": UUID().uuidString,
                "name": "Test 1",
                "age": 18,
                "_acl": [
                    "creator": UUID().uuidString
                ],
                "_kmd": [
                    "lmt": Date().toString(),
                    "ect": Date().toString()
                ]
            ],
            [
                "_id": UUID().uuidString,
                "name": "Test 2",
                "age": 21,
                "_acl": [
                    "creator": UUID().uuidString
                ],
                "_kmd": [
                    "lmt": Date().toString(),
                    "ect": Date().toString()
                ]
            ]
        ]
        
        var _persons: [Person]? = nil
        
        do {
            mockResponse(json: mockObjs)
            defer {
                setURLProtocol(nil)
            }
            
            weak var expectationFind = expectation(description: "Find")
            
            store.find(readPolicy: .forceNetwork) { (persons, error) in
                XCTAssertNotNil(persons)
                XCTAssertNil(error)
                
                XCTAssertEqual(persons?.count, 2)
                
                _persons = persons
                
                expectationFind?.fulfill()
            }
            
            waitForExpectations(timeout: defaultTimeout, handler: { (error) in
                expectationFind = nil
            })
        }
        
        XCTAssertNotNil(_persons)
        
        if let persons = _persons {
            mockResponse(error: timeoutError)
            defer {
                setURLProtocol(nil)
            }
            
            weak var expectationRemove = expectation(description: "Remove")
            
            store.remove(byIds: persons.map { $0.entityId! }, writePolicy: .forceNetwork) { count, error in
                XCTAssertNil(count)
                XCTAssertNotNil(error)
                
                XCTAssertTimeoutError(error)
                
                expectationRemove?.fulfill()
            }
            
            waitForExpectations(timeout: defaultTimeout) { error in
                expectationRemove = nil
            }
        }
    }
    
    func testRemoveEmptyArray() {
        mockResponse(json: [])
        defer {
            setURLProtocol(nil)
        }
        
        weak var expectationRemove = expectation(description: "Remove")
        
        store.remove(byIds: [], writePolicy: .forceNetwork) { count, error in
            XCTAssertNil(count)
            XCTAssertNotNil(error)
            
            XCTAssertEqual(error?.localizedDescription, "ids cannot be an empty array")
            
            expectationRemove?.fulfill()
        }
        
        waitForExpectations(timeout: defaultTimeout) { error in
            expectationRemove = nil
        }
    }
    
    func testRemoveAllTimeoutError() {
        mockResponse(error: timeoutError)
        defer {
            setURLProtocol(nil)
        }
        
        weak var expectationRemove = expectation(description: "Remove")
        
        store.removeAll(.forceNetwork) { count, error in
            XCTAssertNil(count)
            XCTAssertNotNil(error)
            
            XCTAssertTimeoutError(error)
            
            expectationRemove?.fulfill()
        }
        
        waitForExpectations(timeout: defaultTimeout) { error in
            expectationRemove = nil
        }
    }
    
    func testSyncCount() {
        let person = Person()
        person.name = "Test"
        
        let store = DataStore<Person>.collection(.sync)
        
        weak var expectationSave = expectation(description: "Save")
        
        store.save(person) { person, error in
            XCTAssertNotNil(person)
            XCTAssertNil(error)
            
            expectationSave?.fulfill()
        }
        
        waitForExpectations(timeout: defaultTimeout) { error in
            expectationSave = nil
        }
        
        XCTAssertEqual(DataStore<Person>.collection(.network).syncCount(), 0)
        XCTAssertEqual(DataStore<Person>.collection(.sync).syncCount(), 1)
        
        DataStore<Person>.clearCache()
        
        XCTAssertEqual(DataStore<Person>.collection(.sync).syncCount(), 0)
    }
    
    func testClientAppVersion() {
        mockResponse { (request) -> HttpResponse in
            XCTAssertEqual(request.allHTTPHeaderFields?["X-Kinvey-Client-App-Version"], "1.0.0")
            return HttpResponse(json: [])
        }
        defer {
            setURLProtocol(nil)
        }
        
        weak var expectationFind = expectation(description: "Find")
        
        store.find(
            options: Options(
                readPolicy: .forceNetwork,
                clientAppVersion: "1.0.0"
            )
        ) { (result: Result<[Person], Swift.Error>) in
            switch result {
            case .success(let results):
                XCTAssertEqual(results.count, 0)
            case .failure(let error):
                XCTFail(error.localizedDescription)
            }
            
            expectationFind?.fulfill()
        }
        
        waitForExpectations(timeout: defaultTimeout) { error in
            expectationFind = nil
        }
    }
    
    func testCustomRequestProperties() {
        mockResponse { (request) -> HttpResponse in
            XCTAssertEqual(request.allHTTPHeaderFields?["X-Kinvey-Custom-Request-Properties"], "{\"someKey\":\"someValue\"}")
            return HttpResponse(json: [])
        }
        defer {
            setURLProtocol(nil)
        }
        
        weak var expectationFind = expectation(description: "Find")
        
        store.find(
            options: Options(
                readPolicy: .forceNetwork,
                customRequestProperties: [
                    "someKey" : "someValue"
                ]
            )
        ) { (result: Result<[Person], Swift.Error>) in
            switch result {
            case .success(let results):
                XCTAssertEqual(results.count, 0)
            case .failure(let error):
                XCTFail(error.localizedDescription)
            }
            
            expectationFind?.fulfill()
        }
        
        waitForExpectations(timeout: defaultTimeout) { error in
            expectationFind = nil
        }
    }
    
    func testCustomRequestPropertiesPerRequest() {
        mockResponse { (request) -> HttpResponse in
            XCTAssertEqual(request.allHTTPHeaderFields?["X-Kinvey-Custom-Request-Properties"], "{\"someKeyPerRequest\":\"someValuePerRequest\"}")
            return HttpResponse(json: [])
        }
        defer {
            setURLProtocol(nil)
        }
        
        weak var expectationFind = expectation(description: "Find")
        
        let options = Options(
            readPolicy: .forceNetwork,
            customRequestProperties: [
                "someKeyPerRequest" : "someValuePerRequest"
            ]
        )
        store.find(
            options: options
        ) { (result: Result<[Person], Swift.Error>) in
            switch result {
            case .success(let results):
                XCTAssertEqual(results.count, 0)
            case .failure(let error):
                XCTFail(error.localizedDescription)
            }
            
            expectationFind?.fulfill()
        }
        
        waitForExpectations(timeout: defaultTimeout) { error in
            expectationFind = nil
        }
    }
    
    func testDefaultHeaders() {
        class CheckUserAgentHeaderURLProtocol: URLProtocol {
            
            override class func canInit(with request: URLRequest) -> Bool {
                return true
            }
            
            override class func canonicalRequest(for request: URLRequest) -> URLRequest {
                return request
            }
            
            override func startLoading() {
                let userAgent = request.allHTTPHeaderFields?["User-Agent"]
                XCTAssertNotNil(userAgent)
                if let userAgent = userAgent {
                    let regex = try! NSRegularExpression(pattern: "Kinvey SDK (.*)")
                    XCTAssertEqual(regex.matches(in: userAgent, range: NSRange(location: 0, length: userAgent.characters.count)).count, 1)
                }
                
                let deviceInfo = request.allHTTPHeaderFields?["X-Kinvey-Device-Information"]
                XCTAssertNotNil(deviceInfo)
                if let deviceInfo = deviceInfo {
                    #if os(macOS)
                        let regex = try! NSRegularExpression(pattern: "(.*) (.*)")
                    #else
                        let regex = try! NSRegularExpression(pattern: "(.*) (.*) (.*)")
                    #endif
                    XCTAssertEqual(regex.matches(in: deviceInfo, range: NSRange(location: 0, length: deviceInfo.characters.count)).count, 1)
                }
                
                let response = HTTPURLResponse(url: request.url!, statusCode: 200, httpVersion: "1.1", headerFields: [:])!
                client!.urlProtocol(self, didReceive: response, cacheStoragePolicy: .notAllowed)
                
                let responseBody = [[String : Any]]()
                let responseBodyData = try! JSONSerialization.data(withJSONObject: responseBody)
                client!.urlProtocol(self, didLoad: responseBodyData)
                
                client!.urlProtocolDidFinishLoading(self)
            }
            
            override func stopLoading() {
            }
            
        }
        
        setURLProtocol(CheckUserAgentHeaderURLProtocol.self)
        defer {
            setURLProtocol(nil)
        }
        
        weak var expectationFind = expectation(description: "Find")
        
        store.find(readPolicy: .forceNetwork) { results, error in
            XCTAssertNotNil(results)
            XCTAssertNil(error)
            
            expectationFind?.fulfill()
        }
        
        waitForExpectations(timeout: defaultTimeout) { error in
            expectationFind = nil
        }
    }
    
    func testPlusSign() {
        let person = Person()
        person.name = "C++"
        
        var mockJson: JsonDictionary?
        do {
            if useMockData {
                let personId = UUID().uuidString
                mockResponse { (request) -> HttpResponse in
                    var json = try! JSONSerialization.jsonObject(with: request) as! JsonDictionary
                    json[PersistableIdKey] = personId
                    mockJson = json
                    return HttpResponse(json: json)
                }
            }
            defer {
                if useMockData {
                    setURLProtocol(nil)
                }
            }
            
            weak var expectationSave = expectation(description: "Save")
            
            store.save(person, writePolicy: .forceNetwork) { person, error in
                XCTAssertNotNil(person)
                XCTAssertNil(error)
                
                if let person = person {
                    XCTAssertNotNil(person.name)
                    if let name = person.name {
                        XCTAssertEqual(name, "C++")
                    }
                }
                
                expectationSave?.fulfill()
            }
            
            waitForExpectations(timeout: defaultTimeout) { error in
                expectationSave = nil
            }
        }
        
        XCTAssertNotNil(person.personId)
        guard let personId = person.personId else {
            return
        }
        
        do {
            if useMockData {
                mockResponse(json: [mockJson!])
            }
            defer {
                if useMockData {
                    setURLProtocol(nil)
                }
            }
            
            let query = Query(format: "name == %@", "C++")
            
            weak var expectationFind = expectation(description: "Find")
            
            store.find(query, readPolicy: .forceNetwork) { persons, error in
                XCTAssertNotNil(persons)
                XCTAssertNil(error)
                
                if let persons = persons {
                    XCTAssertGreaterThan(persons.count, 0)
                    XCTAssertNotNil(persons.first)
                    if let person = persons.first {
                        XCTAssertNotNil(person.name)
                        if let name = person.name {
                            XCTAssertEqual(name, "C++")
                        }
                    }
                }
                
                expectationFind?.fulfill()
            }
            
            waitForExpectations(timeout: defaultTimeout) { error in
                expectationFind = nil
            }
        }
    }
    
    func testGeolocationQuery() {
        let person = Person()
        person.name = "Victor Barros"
        let latitude = 42.3133521
        let longitude = -71.1271963
        person.geolocation = GeoPoint(latitude: latitude, longitude: longitude)
        
        let json = person.toJSON()
        
        let geolocation = json["geolocation"] as? [Double]
        XCTAssertNotNil(geolocation)
        if let geolocation = geolocation {
            XCTAssertEqual(geolocation[1], latitude)
            XCTAssertEqual(geolocation[0], longitude)
        }
        
        var mockJson: JsonDictionary?
        do {
            if useMockData {
                let personId = UUID().uuidString
                mockResponse(completionHandler: { (request) -> HttpResponse in
                    var json = try! JSONSerialization.jsonObject(with: request) as! JsonDictionary
                    json[PersistableIdKey] = personId
                    mockJson = json
                    return HttpResponse(json: json)
                })
            }
            defer {
                if useMockData {
                    setURLProtocol(nil)
                }
            }
            
            weak var expectationSave = expectation(description: "Save")
            
            store.save(person, writePolicy: .forceNetwork) { person, error in
                XCTAssertNotNil(person)
                XCTAssertNil(error)
                
                if let person = person {
                    XCTAssertNotNil(person.geolocation)
                    if let geolocation = person.geolocation {
                        XCTAssertEqual(geolocation.latitude, latitude)
                        XCTAssertEqual(geolocation.longitude, longitude)
                    }
                }
                
                expectationSave?.fulfill()
            }
            
            waitForExpectations(timeout: defaultTimeout) { error in
                expectationSave = nil
            }
        }
        
        XCTAssertNotNil(person.personId)
        if let personId = person.personId {
            do {
                if useMockData {
                    mockResponse(json: mockJson!)
                }
                defer {
                    if useMockData {
                        setURLProtocol(nil)
                    }
                }
                
                weak var expectationFind = expectation(description: "Find")
                
                store.find(byId: personId, readPolicy: .forceNetwork) { person, error in
                    XCTAssertNotNil(person)
                    XCTAssertNil(error)
                    
                    if let person = person {
                        XCTAssertNotNil(person.geolocation)
                        if let geolocation = person.geolocation {
                            XCTAssertEqual(geolocation.latitude, latitude)
                            XCTAssertEqual(geolocation.longitude, longitude)
                        }
                    }
                    
                    expectationFind?.fulfill()
                }
                
                waitForExpectations(timeout: defaultTimeout) { error in
                    expectationFind = nil
                }
            }
            
            circle(latitude: latitude, longitude: longitude, mockJson: mockJson)
            polygon(latitude: latitude, longitude: longitude, mockJson: mockJson)
        }
    }
    
    func circle(latitude: Double, longitude: Double, mockJson: JsonDictionary?) {
        if useMockData {
            mockResponse(completionHandler: { (request) -> HttpResponse in
                let queryComponents = URLComponents(url: request.url!, resolvingAgainstBaseURL: false)!
                let queryValue = queryComponents.queryItems!.filter { $0.name == "query" }.first!.value!
                let queryJson = try! JSONSerialization.jsonObject(with: queryValue.data(using: .utf8)!) as! JsonDictionary
                let geolocation = queryJson["geolocation"] as! JsonDictionary
                let geoWithin = geolocation["$geoWithin"] as! JsonDictionary
                let centerSphere = geoWithin["$centerSphere"] as! [Any]
                let coordinates = centerSphere[0] as! [Double]
                let location = CLLocation(latitude: coordinates[1], longitude: coordinates[0])
                let radius = (centerSphere[1] as! Double) * 6371000.0
                return HttpResponse(json: [mockJson!].filter({ (item) -> Bool in
                    let itemGeolocation = item["geolocation"] as! [Double]
                    let itemLocation = CLLocation(latitude: itemGeolocation[1], longitude: itemGeolocation[0])
                    return itemLocation.distance(from: location) <= radius
                }))
            })
        }
        defer {
            if useMockData {
                setURLProtocol(nil)
            }
        }
        
        let coordinate = CLLocationCoordinate2D(latitude: 42.3536701, longitude: -71.0607657)
        
        do {
            let query = Query(format: "geolocation = %@", MKCircle(center: coordinate, radius: 8000))
            
            do {
                weak var expectationQuery = expectation(description: "Query")
                
                store.find(query, readPolicy: .forceNetwork) { persons, error in
                    XCTAssertNotNil(persons)
                    XCTAssertNil(error)
                    
                    if let persons = persons {
                        XCTAssertNotNil(persons.first)
                        if let person = persons.first {
                            XCTAssertNotNil(person.geolocation)
                            if let geolocation = person.geolocation {
                                XCTAssertEqual(geolocation.latitude, latitude)
                                XCTAssertEqual(geolocation.longitude, longitude)
                            }
                        }
                    }
                    
                    expectationQuery?.fulfill()
                }
                
                waitForExpectations(timeout: defaultTimeout) { error in
                    expectationQuery = nil
                }
            }
            
            do {
                weak var expectationQuery = expectation(description: "Query")
                
                store.find(query, readPolicy: .forceLocal) { persons, error in
                    XCTAssertNotNil(persons)
                    XCTAssertNil(error)
                    
                    if let persons = persons {
                        XCTAssertNotNil(persons.first)
                        if let person = persons.first {
                            XCTAssertNotNil(person.geolocation)
                            if let geolocation = person.geolocation {
                                XCTAssertEqual(geolocation.latitude, latitude)
                                XCTAssertEqual(geolocation.longitude, longitude)
                            }
                        }
                    }
                    
                    expectationQuery?.fulfill()
                }
                
                waitForExpectations(timeout: defaultTimeout) { error in
                    expectationQuery = nil
                }
            }
        }
        
        do {
            let query = Query(format: "geolocation = %@", MKCircle(center: coordinate, radius: 7000))
            
            do {
                weak var expectationQuery = expectation(description: "Query")
                
                store.find(query, readPolicy: .forceNetwork) { persons, error in
                    XCTAssertNotNil(persons)
                    XCTAssertNil(error)
                    
                    if let persons = persons {
                        XCTAssertNil(persons.first)
                    }
                    
                    expectationQuery?.fulfill()
                }
                
                waitForExpectations(timeout: defaultTimeout) { error in
                    expectationQuery = nil
                }
            }
            
            do {
                weak var expectationQuery = expectation(description: "Query")
                
                store.find(query, readPolicy: .forceLocal) { persons, error in
                    XCTAssertNotNil(persons)
                    XCTAssertNil(error)
                    
                    if let persons = persons {
                        XCTAssertNil(persons.first)
                    }
                    
                    expectationQuery?.fulfill()
                }
                
                waitForExpectations(timeout: defaultTimeout) { error in
                    expectationQuery = nil
                }
            }
        }
    }
    
    func polygon(latitude: Double, longitude: Double, mockJson: JsonDictionary?) {
        if useMockData {
            mockResponse(completionHandler: { (request) -> HttpResponse in
                let queryComponents = URLComponents(url: request.url!, resolvingAgainstBaseURL: false)!
                let queryValue = queryComponents.queryItems!.filter { $0.name == "query" }.first!.value!
                let queryJson = try! JSONSerialization.jsonObject(with: queryValue.data(using: .utf8)!) as! JsonDictionary
                let geolocation = queryJson["geolocation"] as! JsonDictionary
                let geoWithin = geolocation["$geoWithin"] as! JsonDictionary
                let polygonCoordinates = geoWithin["$polygon"] as! [[Double]]
                let locationCoordinates = polygonCoordinates.map {
                    return CLLocationCoordinate2D(latitude: $0[1], longitude: $0[0])
                }
                XCTAssertEqual(polygonCoordinates.first!, polygonCoordinates.last!)
                let polygon = MKPolygon(coordinates: locationCoordinates, count: locationCoordinates.count)
                let path = BezierPath()
                for (i, locationCoordinate) in locationCoordinates.dropLast().enumerated() {
                    let point = CGPoint(x: locationCoordinate.latitude, y: locationCoordinate.longitude)
                    if i == 0 {
                        path.move(to: point)
                    } else {
                        #if os(macOS)
                            path.line(to: point)
                        #else
                            path.addLine(to: point)
                        #endif
                    }
                }
                path.close()
                return HttpResponse(json: [mockJson!].filter { item in
                    let itemGeolocation = item["geolocation"] as! [Double]
                    let itemCoordinate = CLLocationCoordinate2D(latitude: itemGeolocation[1], longitude: itemGeolocation[0])
                    let itemPoint = CGPoint(x: itemCoordinate.latitude, y: itemCoordinate.longitude)
                    return path.contains(itemPoint)
                })
            })
        }
        defer {
            if useMockData {
                setURLProtocol(nil)
            }
        }
        
        do {
            let coordinates = [
                CLLocationCoordinate2D(latitude: 42.30229389364817, longitude: -71.14453953484005),
                CLLocationCoordinate2D(latitude: 42.30118020216164, longitude: -71.1079452220194),
                CLLocationCoordinate2D(latitude: 42.32628747399235, longitude: -71.10934348908339),
                CLLocationCoordinate2D(latitude: 42.32487077061631, longitude: -71.14195570326387),
                CLLocationCoordinate2D(latitude: 42.30229389364817, longitude: -71.14453953484005),
            ]
            let polygon = MKPolygon(coordinates: coordinates, count: coordinates.count)
            let query = Query(format: "geolocation = %@", polygon)
            
            do {
                weak var expectationQuery = expectation(description: "Query")
                
                store.find(query, readPolicy: .forceNetwork) { persons, error in
                    XCTAssertNotNil(persons)
                    XCTAssertNil(error)
                    
                    if let persons = persons {
                        XCTAssertNotNil(persons.first)
                        if let person = persons.first {
                            XCTAssertNotNil(person.geolocation)
                            if let geolocation = person.geolocation {
                                XCTAssertEqual(geolocation.latitude, latitude)
                                XCTAssertEqual(geolocation.longitude, longitude)
                            }
                        }
                    }
                    
                    expectationQuery?.fulfill()
                }
                
                waitForExpectations(timeout: defaultTimeout) { error in
                    expectationQuery = nil
                }
            }
            
            do {
                weak var expectationQuery = expectation(description: "Query")
                
                store.find(query, readPolicy: .forceLocal) { persons, error in
                    XCTAssertNotNil(persons)
                    XCTAssertNil(error)
                    
                    if let persons = persons {
                        XCTAssertNotNil(persons.first)
                        if let person = persons.first {
                            XCTAssertNotNil(person.geolocation)
                            if let geolocation = person.geolocation {
                                XCTAssertEqual(geolocation.latitude, latitude)
                                XCTAssertEqual(geolocation.longitude, longitude)
                            }
                        }
                    }
                    
                    expectationQuery?.fulfill()
                }
                
                waitForExpectations(timeout: defaultTimeout) { error in
                    expectationQuery = nil
                }
            }
        }
        
        do {
            let coordinates = [
                CLLocationCoordinate2D(latitude: 42.31363114297847, longitude: -71.12454163288896),
                CLLocationCoordinate2D(latitude: 42.31359338001615, longitude: -71.11596352589291),
                CLLocationCoordinate2D(latitude: 42.32375212671243, longitude: -71.11492645316849),
                CLLocationCoordinate2D(latitude: 42.32182013184487, longitude: -71.13022491168071),
                CLLocationCoordinate2D(latitude: 42.31363114297847, longitude: -71.12454163288896),
            ]
            let polygon = MKPolygon(coordinates: coordinates, count: coordinates.count)
            let query = Query(format: "geolocation = %@", polygon)
            
            do {
                weak var expectationQuery = expectation(description: "Query")
                
                store.find(query, readPolicy: .forceNetwork) { persons, error in
                    XCTAssertNotNil(persons)
                    XCTAssertNil(error)
                    
                    if let persons = persons {
                        XCTAssertNil(persons.first)
                    }
                    
                    expectationQuery?.fulfill()
                }
                
                waitForExpectations(timeout: defaultTimeout) { error in
                    expectationQuery = nil
                }
            }
            
            do {
                weak var expectationQuery = expectation(description: "Query")
                
                store.find(query, readPolicy: .forceLocal) { persons, error in
                    XCTAssertNotNil(persons)
                    XCTAssertNil(error)
                    
                    if let persons = persons {
                        XCTAssertNil(persons.first)
                    }
                    
                    expectationQuery?.fulfill()
                }
                
                waitForExpectations(timeout: defaultTimeout) { error in
                    expectationQuery = nil
                }
            }
        }
    }
    
    func testGroupCustomAggregation() {
        signUp()
        
        let store = DataStore<Person>.collection(.network)
        
        if useMockData {
            mockResponse(json: [
                ["sum" : 926]
            ])
        }
        defer {
            if useMockData {
                setURLProtocol(nil)
            }
        }
        
        weak var expectationGroup = expectation(description: "Group")
        
        store.group(
            initialObject: ["sum" : 0],
            reduceJSFunction: "function(doc,out) { out.sum += doc.age; }",
            condition: NSPredicate(format: "age > %@", NSNumber(value: 18))
        ) { (results, error) in
            XCTAssertNotNil(results)
            XCTAssertNil(error)
            
            if let (person, result) = results?.first {
                XCTAssertNil(person.name)
                XCTAssertNotNil(result["sum"] as? Int)
            }
            
            expectationGroup?.fulfill()
        }
        
        waitForExpectations(timeout: defaultTimeout) { error in
            expectationGroup = nil
        }
    }
    
    func testGroupCustomAggregationByName() {
        signUp()
        
        let store = DataStore<Person>.collection(.network)
        
        if useMockData {
            mockResponse(json: [
                [
                    "name" : "Victor",
                    "sum" : 926
                ]
            ])
        }
        defer {
            if useMockData {
                setURLProtocol(nil)
            }
        }
        
        weak var expectationGroup = expectation(description: "Group")
        
        store.group(
            keys: ["name"],
            initialObject: ["sum" : 0],
            reduceJSFunction: "function(doc,out) { out.sum += doc.age; }",
            condition: NSPredicate(format: "age > %@", NSNumber(value: 18))
        ) { (results, error) in
            XCTAssertNotNil(results)
            XCTAssertNil(error)
            
            if let (person, result) = results?.first {
                XCTAssertNotNil(person.name)
                XCTAssertNotNil(result["sum"] as? Int)
            }
            
            expectationGroup?.fulfill()
        }
        
        waitForExpectations(timeout: defaultTimeout) { error in
            expectationGroup = nil
        }
    }
    
    func testGroupCustomAggregationTimeoutError() {
        signUp()
        
        let store = DataStore<Person>.collection(.network)
        
        mockResponse(error: timeoutError)
        defer {
            setURLProtocol(nil)
        }
        
        weak var expectationGroup = expectation(description: "Group")
        
        store.group(
            initialObject: ["sum" : 0],
            reduceJSFunction: "function(doc,out) { out.sum += doc.age; }",
            condition: NSPredicate(format: "age > %@", NSNumber(value: 18))
        ) { (results, error) in
            XCTAssertNil(results)
            XCTAssertNotNil(error)
            
            XCTAssertTimeoutError(error)
            
            expectationGroup?.fulfill()
        }
        
        waitForExpectations(timeout: defaultTimeout) { error in
            expectationGroup = nil
        }
    }
    
    func testGroupAggregationCountByName() {
        signUp()
        
        let store = DataStore<Person>.collection(.network)
        
        if useMockData {
            mockResponse(json: [
                [
                    "name" : "Victor",
                    "count" : 32
                ]
            ])
        }
        defer {
            if useMockData {
                setURLProtocol(nil)
            }
        }
        
        weak var expectationGroup = expectation(description: "Group")
        
        store.group(
            count: ["name"],
            countType: Int.self,
            condition: NSPredicate(format: "age > %@", NSNumber(value: 18))
        ) { (results, error) in
            XCTAssertNotNil(results)
            XCTAssertNil(error)
            
            if let results = results {
                XCTAssertGreaterThanOrEqual(results.count, 0)
                
                if let first = results.first {
                    XCTAssertNotNil(first.value.name)
                    XCTAssertEqual(first.count, 32)
                }
            }
            
            expectationGroup?.fulfill()
        }
        
        waitForExpectations(timeout: defaultTimeout) { error in
            expectationGroup = nil
        }
    }
    
    func testGroupAggregationCountByNameTimeoutError() {
        signUp()
        
        let store = DataStore<Person>.collection(.network)
        
        mockResponse(error: timeoutError)
        defer {
            setURLProtocol(nil)
        }
        
        weak var expectationGroup = expectation(description: "Group")
        
        store.group(
            count: ["name"],
            countType: Int.self,
            condition: NSPredicate(format: "age > %@", NSNumber(value: 18))
        ) { (results, error) in
            XCTAssertNil(results)
            XCTAssertNotNil(error)
            
            XCTAssertTimeoutError(error)
            
            expectationGroup?.fulfill()
        }
        
        waitForExpectations(timeout: defaultTimeout) { error in
            expectationGroup = nil
        }
    }
    
    func testGroupAggregationSumByName() {
        signUp()
        
        let store = DataStore<Person>.collection(.network)
        
        if useMockData {
            mockResponse(json: [
                [
                    "name" : "Victor",
                    "sum" : 926.2
                ]
            ])
        }
        defer {
            if useMockData {
                setURLProtocol(nil)
            }
        }
        
        weak var expectationGroup = expectation(description: "Group")
        
        store.group(
            keys: ["name"],
            sum: "age",
            sumType: Double.self,
            condition: NSPredicate(format: "age > %@", NSNumber(value: 18))
        ) { (results, error) in
            XCTAssertNotNil(results)
            XCTAssertNil(error)
            
            if let results = results {
                XCTAssertGreaterThanOrEqual(results.count, 0)
                
                if let first = results.first {
                    XCTAssertNotNil(first.value.name)
                    XCTAssertEqual(first.sum, 926.2)
                }
            }
            
            expectationGroup?.fulfill()
        }
        
        waitForExpectations(timeout: defaultTimeout) { error in
            expectationGroup = nil
        }
    }
    
    func testGroupAggregationSumByNameTimeoutError() {
        signUp()
        
        let store = DataStore<Person>.collection(.network)
        
        mockResponse(error: timeoutError)
        defer {
            setURLProtocol(nil)
        }
        
        weak var expectationGroup = expectation(description: "Group")
        
        store.group(
            keys: ["name"],
            sum: "age",
            sumType: Double.self,
            condition: NSPredicate(format: "age > %@", NSNumber(value: 18))
        ) { (results, error) in
            XCTAssertNil(results)
            XCTAssertNotNil(error)
            
            XCTAssertTimeoutError(error)
            
            expectationGroup?.fulfill()
        }
        
        waitForExpectations(timeout: defaultTimeout) { error in
            expectationGroup = nil
        }
    }
    
    func testGroupAggregationAvgByName() {
        signUp()
        
        let store = DataStore<Person>.collection(.network)
        
        if useMockData {
            mockResponse(json: [
                [
                    "name" : "Victor",
                    "sum" : 926,
                    "count" : 32,
                    "avg" : 28.9375
                ]
            ])
        }
        defer {
            if useMockData {
                setURLProtocol(nil)
            }
        }
        
        weak var expectationGroup = expectation(description: "Group")
        
        store.group(
            keys: ["name"],
            avg: "age",
            avgType: Double.self,
            condition: NSPredicate(format: "age > %@", NSNumber(value: 18))
        ) { (result, error) in
            XCTAssertNotNil(result)
            XCTAssertNil(error)
            
            if let result = result {
                XCTAssertGreaterThanOrEqual(result.count, 0)
                
                if let first = result.first {
                    XCTAssertNotNil(first.value.name)
                    XCTAssertEqual(first.avg, 28.9375)
                }
            }
            
            expectationGroup?.fulfill()
        }
        
        waitForExpectations(timeout: defaultTimeout) { error in
            expectationGroup = nil
        }
    }
    
    func testGroupAggregationAvgByNameTimeoutError() {
        signUp()
        
        let store = DataStore<Person>.collection(.network)
        
        mockResponse(error: timeoutError)
        defer {
            setURLProtocol(nil)
        }
        
        weak var expectationGroup = expectation(description: "Group")
        
        store.group(
            keys: ["name"],
            avg: "age",
            avgType: Double.self,
            condition: NSPredicate(format: "age > %@", NSNumber(value: 18))
        ) { (result, error) in
            XCTAssertNil(result)
            XCTAssertNotNil(error)
            
            XCTAssertTimeoutError(error)
            
            expectationGroup?.fulfill()
        }
        
        waitForExpectations(timeout: defaultTimeout) { error in
            expectationGroup = nil
        }
    }
    
    func testGroupAggregationMinByName() {
        signUp()
        
        let store = DataStore<Person>.collection(.network)
        
        if useMockData {
            mockResponse(json: [
                [
                    "name" : "Victor",
                    "min" : 27.6
                ]
            ])
        }
        defer {
            if useMockData {
                setURLProtocol(nil)
            }
        }
        
        weak var expectationGroup = expectation(description: "Group")
        
        store.group(
            keys: ["name"],
            min: "age",
            minType: Float.self,
            condition: NSPredicate(format: "age > %@", NSNumber(value: 18))
        ) { (result, error) in
            XCTAssertNotNil(result)
            XCTAssertNil(error)
            
            if let result = result {
                XCTAssertGreaterThanOrEqual(result.count, 0)
                
                if let (person, min) = result.first {
                    XCTAssertNotNil(person.name)
                    XCTAssertEqual(min, 27.6)
                }
            }
            
            expectationGroup?.fulfill()
        }
        
        waitForExpectations(timeout: defaultTimeout) { error in
            expectationGroup = nil
        }
    }
    
    func testGroupAggregationMinByNameTimeoutError() {
        signUp()
        
        let store = DataStore<Person>.collection(.network)
        
        mockResponse(error: timeoutError)
        defer {
            setURLProtocol(nil)
        }
        
        weak var expectationGroup = expectation(description: "Group")
        
        store.group(
            keys: ["name"],
            min: "age",
            minType: Float.self,
            condition: NSPredicate(format: "age > %@", NSNumber(value: 18))
        ) { (result, error) in
            XCTAssertNil(result)
            XCTAssertNotNil(error)
            
            XCTAssertTimeoutError(error)
            
            expectationGroup?.fulfill()
        }
        
        waitForExpectations(timeout: defaultTimeout) { error in
            expectationGroup = nil
        }
    }
    
    func testGroupAggregationMaxByName() {
        signUp()
        
        let store = DataStore<Person>.collection(.network)
        
        if useMockData {
            mockResponse(json: [
                [
                    "name" : "Victor",
                    "max" : 30.5
                ]
            ])
        }
        defer {
            if useMockData {
                setURLProtocol(nil)
            }
        }
        
        weak var expectationGroup = expectation(description: "Group")
        
        store.group(
            keys: ["name"],
            max: "age",
            maxType: Float.self,
            condition: NSPredicate(format: "age > %@", NSNumber(value: 18))
        ) { (result, error) in
            XCTAssertNotNil(result)
            XCTAssertNil(error)
            
            if let result = result {
                XCTAssertGreaterThanOrEqual(result.count, 0)
                
                if let (person, max) = result.first {
                    XCTAssertNotNil(person.name)
                    XCTAssertEqual(max, 30.5)
                }
            }
            
            expectationGroup?.fulfill()
        }
        
        waitForExpectations(timeout: defaultTimeout) { error in
            expectationGroup = nil
        }
    }
    
    func testGroupAggregationMaxByNameTimeoutError() {
        signUp()
        
        let store = DataStore<Person>.collection(.network)
        
        mockResponse(error: timeoutError)
        defer {
            setURLProtocol(nil)
        }
        
        weak var expectationGroup = expectation(description: "Group")
        
        store.group(
            keys: ["name"],
            max: "age",
            maxType: Float.self,
            condition: NSPredicate(format: "age > %@", NSNumber(value: 18))
        ) { (result, error) in
            XCTAssertNil(result)
            XCTAssertNotNil(error)
            
            XCTAssertTimeoutError(error)
            
            expectationGroup?.fulfill()
        }
        
        waitForExpectations(timeout: defaultTimeout) { error in
            expectationGroup = nil
        }
    }
    
    func testGroupCustomResultKey() {
        expect { () -> Void in
            let _ = Aggregation.custom(keys: [], initialObject: [:], reduceJSFunction: "").resultKey
        }.to(throwAssertion())
    }
    
    func testRemoveByEmptyId() {
        let store = DataStore<Person>.collection(.network)
        expect { () -> Void in
            store.remove(byId: "") { count, error in
                XCTFail()
            }
        }.to(throwAssertion())
    }
    
    func testAutoPaginationDisabled() {
        let store = DataStore<Products>.collection(.network)
        
        mockResponse(
            statusCode: 400,
            json: [
                "error" : "ResultSetSizeExceeded",
                "description" : "Your query produced more than 10,000 results. Please rewrite your query to be more selective.",
                "debug" : "Your query returned 320193 results"
            ]
        )
        defer {
            setURLProtocol(nil)
        }
        
        weak var expectationFind = expectation(description: "Find")
        
        store.find { (result: Result<AnyRandomAccessCollection<Products>, Swift.Error>) in
            switch result {
            case .success:
                XCTFail()
            case .failure(let error):
                if let error = error as? Kinvey.Error {
                    switch error {
                    case .resultSetSizeExceeded(let debug, let description):
                        XCTAssertEqual(description, "Your query produced more than 10,000 results. Please rewrite your query to be more selective.")
                        XCTAssertTrue(debug.hasPrefix("Your query returned "))
                        XCTAssertTrue(debug.hasSuffix(" results"))
                    default:
                        XCTFail(error.debugDescription)
                    }
                } else {
                    XCTFail(error.localizedDescription)
                }
            }
            
            expectationFind?.fulfill()
        }
        
        waitForExpectations(timeout: defaultTimeout) { error in
            expectationFind = nil
        }
    }
    
    func testAutoPaginationEnabledNetworkOnly() {
        var count = 0
        mockResponse { (request) -> HttpResponse in
            defer {
                count += 1
            }
            switch count {
            case 0:
                return HttpResponse(json: ["count" : 21000])
            case 1...3:
                var json = [[String : Any]]()
                let limit = count == 3 ? 1000 : 10000
                for i in 0 ..< limit {
                    json.append([
                        "_id" : UUID().uuidString,
                        "Description" : UUID().uuidString,
                        "_acl" : [
                            "creator" : UUID().uuidString
                        ],
                        "_kmd" : [
                            "lmt" : Date().toString(),
                            "ect" : Date().toString()
                        ]
                    ])
                }
                return HttpResponse(json: json)
            default:
                Swift.fatalError()
            }
        }
        defer {
            setURLProtocol(nil)
        }
        
        let store = DataStore<Products>.collection(.network, autoPagination: true)
        
        weak var expectationFind = expectation(description: "Find")
        
        store.find { (result: Result<AnyRandomAccessCollection<Products>, Swift.Error>) in
            switch result {
            case .success(let products):
                XCTAssertEqual(products.count, 21000)
            case .failure(let error):
                XCTFail(error.localizedDescription)
            }
            
            expectationFind?.fulfill()
        }
        
        waitForExpectations(timeout: defaultTimeout * 5) { error in
            expectationFind = nil
        }
    }
    
    func testAutoPaginationEnabled() {
        var count = 0
        mockResponse { (request) -> HttpResponse in
            defer {
                count += 1
            }
            switch count {
            case 0:
                return HttpResponse(json: ["count" : 21000])
            case 1...3:
                var json = [[String : Any]]()
                let limit = count == 3 ? 1000 : 10000
                for i in 0 ..< limit {
                    json.append([
                        "_id" : UUID().uuidString,
                        "Description" : UUID().uuidString,
                        "_acl" : [
                            "creator" : UUID().uuidString
                        ],
                        "_kmd" : [
                            "lmt" : Date().toString(),
                            "ect" : Date().toString()
                        ]
                    ])
                }
                return HttpResponse(json: json)
            default:
                Swift.fatalError()
            }
        }
        defer {
            setURLProtocol(nil)
        }
        
        let store = DataStore<Products>.collection(.sync, autoPagination: true)
        
        weak var expectationFind = expectation(description: "Find")
        
        store.find(options: Options(readPolicy: .forceNetwork)) { (result: Result<AnyRandomAccessCollection<Products>, Swift.Error>) in
            switch result {
            case .success(let products):
                XCTAssertEqual(products.count, 21000)
            case .failure(let error):
                XCTFail(error.localizedDescription)
            }
            
            expectationFind?.fulfill()
        }
        
        waitForExpectations(timeout: defaultTimeout * 5) { error in
            expectationFind = nil
        }
    }
    
}

class Products: Entity {
    
    @objc dynamic var desc: String?
    
    override static func collectionName() -> String {
        return "products"
    }
    
    override func propertyMapping(_ map: Map) {
        super.propertyMapping(map)
        
        desc <- ("desc", map["Description"])
    }
    
}
