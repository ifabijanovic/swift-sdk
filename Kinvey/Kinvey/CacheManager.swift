//
//  CacheManager.swift
//  Kinvey
//
//  Created by Victor Barros on 2016-01-20.
//  Copyright © 2016 Kinvey. All rights reserved.
//

import Foundation

#if canImport(RealmSwift)
import Realm
import RealmSwift
#endif

internal class CacheManager: NSObject {
    
    fileprivate let persistenceId: String
    fileprivate let encryptionKey: Data?
    fileprivate let schemaVersion: UInt64
    
    init(persistenceId: String, encryptionKey: Data? = nil, schemaVersion: UInt64 = 0) {
        self.persistenceId = persistenceId
        self.encryptionKey = encryptionKey
        self.schemaVersion = schemaVersion
    }
    
    func cache<T: Persistable>(fileURL: URL? = nil, type: T.Type) throws -> AnyCache<T>? where T: NSObject {
        let fileManager = FileManager.default
        if let fileURL = fileURL {
            do {
                let baseURL = fileURL.deletingLastPathComponent()
                if !fileManager.fileExists(atPath: baseURL.path) {
                    try! fileManager.createDirectory(at: baseURL, withIntermediateDirectories: true, attributes: nil)
                }
            }
        }
        
#if canImport(RealmSwift)
        return AnyCache(try RealmCache<T>(persistenceId: persistenceId, fileURL: fileURL, encryptionKey: encryptionKey, schemaVersion: schemaVersion))
#else
        return nil
#endif
    }
    
    func fileCache<FileType: File>(fileURL: URL? = nil) -> AnyFileCache<FileType>? {
#if canImport(RealmSwift)
        return AnyFileCache(RealmFileCache<FileType>(persistenceId: persistenceId, fileURL: fileURL, encryptionKey: encryptionKey, schemaVersion: schemaVersion))
#else
        return nil
#endif
    }
    
    func clearAll(_ tag: String? = nil) {
#if canImport(RealmSwift)
        let basePath = cacheBasePath.appendingPathComponent(persistenceId)
        
        let fileManager = FileManager.default
        
        var isDirectory = ObjCBool(false)
        let exists = fileManager.fileExists(atPath: basePath.path, isDirectory: &isDirectory)
        if exists && isDirectory.boolValue {
            var array = try! fileManager.subpathsOfDirectory(atPath: basePath.path)
            array = array.filter({ (path) -> Bool in
                return path.hasSuffix(".realm") && (tag == nil || path.caseInsensitiveCompare(tag! + ".realm") == .orderedSame)
            })
            for realmFile in array {
                var realmConfiguration = Realm.Configuration.defaultConfiguration
                realmConfiguration.fileURL = basePath.appendingPathComponent(realmFile)
                if let encryptionKey = encryptionKey {
                    realmConfiguration.encryptionKey = encryptionKey
                }
                if let realm = try? Realm(configuration: realmConfiguration), !realm.isEmpty {
                    try! realm.write {
                        realm.deleteAll()
                    }
                }
            }
        }
#endif
    }
    
}
