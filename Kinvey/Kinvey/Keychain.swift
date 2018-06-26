//
//  Keychain.swift
//  Kinvey
//
//  Created by Victor Barros on 2016-03-04.
//  Copyright © 2016 Kinvey. All rights reserved.
//

import Foundation

#if canImport(KeychainAccess)
import KeychainAccess
#else
class MemoryKeychain {
    
    var attributes = [String : Any]()
    
    init(_ service: String = UUID().uuidString) {
        
    }
    
    func removeAll() throws {
        
    }
    
    subscript(_ key: String) -> Any? {
        get {
            return attributes[key]
        }
        set {
            attributes[key] = newValue
        }
    }
    
    subscript(_ key: String) -> String? {
        get {
            return attributes[key] as? String
        }
        set {
            attributes[key] = newValue
        }
    }
    
    subscript(data key: String) -> Data? {
        get {
            return attributes[key] as? Data
        }
        set {
            self[key] = newValue
        }
    }
    
}
#endif

class Keychain {
    
    private let appKey: String?
    private let accessGroup: String?
    private let _client: Client?
    
    #if canImport(KeychainAccess)
    internal let keychain: KeychainAccess.Keychain
    #else
    internal let keychain: MemoryKeychain
    #endif
    
    private var client: Client {
        return _client ?? sharedClient
    }
    
    init() {
        self.appKey = nil
        self.accessGroup = nil
        self._client = nil
        #if canImport(KeychainAccess)
        self.keychain = KeychainAccess.Keychain().accessibility(.afterFirstUnlockThisDeviceOnly)
        #else
        self.keychain = MemoryKeychain()
        #endif
    }
    
    init(appKey: String, client: Client) {
        self.appKey = appKey
        self.accessGroup = nil
        self._client = client
        let service = "com.kinvey.Kinvey.\(appKey)"
        #if canImport(KeychainAccess)
        self.keychain = KeychainAccess.Keychain(service: service).accessibility(.afterFirstUnlockThisDeviceOnly)
        #else
        self.keychain = MemoryKeychain(service)
        #endif
    }
    
    init(accessGroup: String, client: Client) {
        self.accessGroup = accessGroup
        self.appKey = nil
        self._client = client
        #if canImport(KeychainAccess)
        self.keychain = KeychainAccess.Keychain(service: accessGroup, accessGroup: accessGroup).accessibility(.afterFirstUnlockThisDeviceOnly)
        #else
        self.keychain = MemoryKeychain(accessGroup)
        #endif
    }
    
    enum Key: String {
        
        case deviceToken = "deviceToken"
        case user = "user"
        case clientId = "client_id"
        case kinveyAuth = "kinveyAuth"
        case defaultEncryptionKey = "defaultEncryptionKey"
        case deviceId = "deviceId"
        
    }
    
    var deviceToken: Data? {
        get {
            return keychain[data: .deviceToken]
        }
        set {
            keychain[data: .deviceToken] = newValue
        }
    }
    
    var user: User? {
        get {
            guard let data = keychain[.user]?.data(using: .utf8),
                let jsonObject = try? JSONSerialization.jsonObject(with: data),
                let json = jsonObject as? [String : Any],
                let user = try? client.jsonParser.parseUser(client.userType, from: json)
            else {
                return nil
            }
            if let socialIdentity = json[User.CodingKeys.socialIdentity] as? [String : Any] {
                user.socialIdentityDictionary = socialIdentity
            }
            return user
        }
        set {
            guard let newValue = newValue, var json = try? client.jsonParser.toJSON(newValue) else {
                keychain[.user] = nil
                return
            }
            if let socialIdentity = newValue.socialIdentityDictionary {
                json[User.CodingKeys.socialIdentity] = socialIdentity
            }
            guard let data = try? JSONSerialization.data(withJSONObject: json) else {
                keychain[.user] = nil
                return
            }
            let jsonString = String(data: data, encoding: .utf8)
            keychain[.user] = jsonString
        }
    }
    
    var clientId: String? {
        get {
            return keychain[.clientId]
        }
        set {
            keychain[.clientId] = newValue
        }
    }
    
    var kinveyAuth: [String : Any]? {
        get {
            if let jsonString = keychain[.kinveyAuth],
                let data = jsonString.data(using: .utf8),
                let jsonObject = try? JSONSerialization.jsonObject(with: data)
            {
                return jsonObject as? JsonDictionary
            }
            return nil
        }
        set {
            if let newValue = newValue,
                let data = try? JSONSerialization.data(withJSONObject: newValue)
            {
                keychain[.kinveyAuth] = String(data: data, encoding: .utf8)
            } else {
                keychain[.kinveyAuth] = nil
            }
        }
    }
    
    var defaultEncryptionKey: Data? {
        get {
            return keychain[data: .defaultEncryptionKey]
        }
        set {
            keychain[data: .defaultEncryptionKey] = newValue
        }
    }
    
    func removeAll() throws {
        try keychain.removeAll()
    }
    
}

#if canImport(KeychainAccess)
extension KeychainAccess.Keychain {
    
    subscript(key: Keychain.Key) -> String? {
        get {
            return self[key.rawValue]
        }
        set {
            self[key.rawValue] = newValue
        }
    }
    
    subscript(data key: Keychain.Key) -> Data? {
        get {
            return self[data: key.rawValue]
        }
        set {
            self[data: key.rawValue] = newValue
        }
    }
    
}
#else
extension MemoryKeychain {
    
        subscript(_ key: Keychain.Key) -> String? {
            get {
                return self[key.rawValue]
            }
            set {
                self[key.rawValue] = newValue
            }
        }
    
        subscript(data key: Keychain.Key) -> Data? {
            get {
                return self[data: key.rawValue]
            }
            set {
                self[data: key.rawValue] = newValue
            }
        }
    
}
#endif
