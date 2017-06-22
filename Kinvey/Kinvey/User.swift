//
//  User.swift
//  Kinvey
//
//  Created by Victor Barros on 2015-12-08.
//  Copyright © 2015 Kinvey. All rights reserved.
//

import Foundation
import PromiseKit
import ObjectMapper

#if os(iOS) || os(OSX)
    import SafariServices
#endif

/// Class that represents an `User`.
open class User: NSObject, Credential, Mappable {
    
    /// Username Key.
    open static let PersistableUsernameKey = "username"
    
    public typealias UserHandler<U: User> = (U?, Swift.Error?) -> Void
    public typealias UsersHandler<U: User> = ([U]?, Swift.Error?) -> Void
    public typealias VoidHandler = (Swift.Error?) -> Void
    public typealias BoolHandler = (Bool, Swift.Error?) -> Void
    
    /// `_id` property of the user.
    open var userId: String {
        return _userId!
    }
    
    @objc private dynamic var _userId: String?
    
    /// `_acl` property of the user.
    open fileprivate(set) var acl: Acl?
    
    /// `_kmd` property of the user.
    open fileprivate(set) var metadata: UserMetadata?
    
    /// `_socialIdentity` property of the user.
    open fileprivate(set) var socialIdentity: UserSocialIdentity?
    
    /// `username` property of the user.
    open var username: String?
    
    /// `email` property of the user.
    open var email: String?
    
    internal var client: Client
    
    internal var realtimeRouter: RealtimeRouter?
    
    /// Creates a new `User` taking (optionally) a username and password. If no `username` or `password` was provided, random values will be generated automatically.
    @discardableResult
    open class func signup<U: User>(username: String? = nil, password: String? = nil, user: U? = nil, client: Client = Kinvey.sharedClient, completionHandler: UserHandler<U>? = nil) -> Request {
        return signup(
            username: username,
            password: password,
            user: user,
            client: client
        ) { (result: Result<U, Swift.Error>) in
            switch result {
            case .success(let user):
                completionHandler?(user, nil)
            case .failure(let error):
                completionHandler?(nil, error)
            }
        }
    }
    
    /// Creates a new `User` taking (optionally) a username and password. If no `username` or `password` was provided, random values will be generated automatically.
    @discardableResult
    open class func signup<U: User>(username: String? = nil, password: String? = nil, user: U? = nil, client: Client = Kinvey.sharedClient, completionHandler: ((Result<U, Swift.Error>) -> Void)? = nil) -> Request {
        if let error = client.validate() {
            DispatchQueue.main.async {
                completionHandler?(.failure(error))
            }
            return LocalRequest()
        }

        let request = client.networkRequestFactory.buildUserSignUp(username: username, password: password, user: user)
        Promise<U> { fulfill, reject in
            request.execute() { (data, response, error) in
                if let response = response, response.isOK, let user = client.responseParser.parseUser(data) as? U {
                    client.activeUser = user
                    fulfill(user)
                } else {
                    reject(buildError(data, response, error, client))
                }
            }
        }.then { user in
            completionHandler?(.success(user))
        }.catch { error in
            completionHandler?(.failure(error))
        }
        return request
    }
    
    /// Deletes a `User` by the `userId` property.
    @discardableResult
    open class func destroy(userId: String, hard: Bool = true, client: Client = Kinvey.sharedClient, completionHandler: ((Result<Void, Swift.Error>) -> Void)? = nil) -> Request {
        let request = client.networkRequestFactory.buildUserDelete(userId: userId, hard: hard)
        Promise<Void> { fulfill, reject in
            request.execute() { (data, response, error) in
                if let response = response, response.isOK {
                    if let activeUser = client.activeUser, activeUser.userId == userId {
                        client.activeUser = nil
                    }
                    fulfill(())
                } else {
                    reject(buildError(data, response, error, client))
                }
            }
        }.then { void in
            completionHandler?(.success(void))
        }.catch { error in
            completionHandler?(.failure(error))
        }
        return request
    }
    
    /// Deletes the `User`.
    @discardableResult
    open func destroy(hard: Bool = true, completionHandler: ((Result<Void, Swift.Error>) -> Void)? = nil) -> Request {
        return User.destroy(userId: userId, hard: hard, client: client, completionHandler: completionHandler)
    }
    
    /**
     Sign in a user with a social identity.
     - parameter authSource: Authentication source enum
     - parameter authData: Authentication data from the social provider
     - parameter client: Define the `Client` to be used for all the requests for the `DataStore` that will be returned. Default value: `Kinvey.sharedClient`
     - parameter completionHandler: Completion handler to be called once the response returns from the server
     */
    @discardableResult
    open class func login<U: User>(authSource: AuthSource, _ authData: [String : Any], createIfNotExists: Bool = true, clientId: String? = nil, client: Client = Kinvey.sharedClient, completionHandler: UserHandler<U>? = nil) -> Request {
        return login(
            authSource: authSource,
            authData,
            createIfNotExists: createIfNotExists,
            client: client
        ) { (result: Result<U, Swift.Error>) in
            switch result {
            case .success(let user):
                completionHandler?(user, nil)
            case .failure(let error):
                completionHandler?(nil, error)
            }
        }
    }
    
    /**
     Sign in a user with a social identity.
     - parameter authSource: Authentication source enum
     - parameter authData: Authentication data from the social provider
     - parameter client: Define the `Client` to be used for all the requests for the `DataStore` that will be returned. Default value: `Kinvey.sharedClient`
     - parameter completionHandler: Completion handler to be called once the response returns from the server
     */
    @discardableResult
    open class func login<U: User>(authSource: AuthSource, _ authData: [String : Any], createIfNotExists: Bool = true, clientId: String? = nil, client: Client = Kinvey.sharedClient, completionHandler: ((Result<U, Swift.Error>) -> Void)? = nil) -> Request {
        if let error = client.validate() {
            DispatchQueue.main.async {
                completionHandler?(.failure(error))
            }
            return LocalRequest()
        }
        
        let requests = MultiRequest()
        Promise<U> { fulfill, reject in
            let request = client.networkRequestFactory.buildUserSocialLogin(authSource, authData: authData)
            request.execute() { (data, response, error) in
                if let response = response {
                    if response.isOK, let user = client.responseParser.parseUser(data) as? U {
                        fulfill(user)
                    } else if response.isNotFound, createIfNotExists {
                        let request = client.networkRequestFactory.buildUserSocialCreate(authSource, authData: authData)
                        request.execute { (data, response, error) in
                            if let response = response, response.isOK, let user = client.responseParser.parseUser(data) as? U {
                                fulfill(user)
                            } else {
                                reject(buildError(data, response, error, client))
                            }
                        }
                        requests += request
                    } else {
                        reject(buildError(data, response, error, client))
                    }
                } else {
                    reject(buildError(data, response, error, client))
                }
            }
            requests += request
        }.then { user -> Void in
            client.activeUser = user
            client.clientId = clientId
            completionHandler?(.success(user))
        }.catch { error in
            completionHandler?(.failure(error))
        }
        return requests
    }
    
    /// Sign in a user and set as a current active user.
    @discardableResult
    open class func login<U: User>(username: String, password: String, client: Client = Kinvey.sharedClient, completionHandler: UserHandler<U>? = nil) -> Request {
        return login(
            username: username,
            password: password,
            client: client
        ) { (result: Result<U, Swift.Error>) in
            switch result {
            case .success(let user):
                completionHandler?(user, nil)
            case .failure(let error):
                completionHandler?(nil, error)
            }
        }
    }
    
    /// Sign in a user and set as a current active user.
    @discardableResult
    open class func login<U: User>(username: String, password: String, client: Client = Kinvey.sharedClient, completionHandler: ((Result<U, Swift.Error>) -> Void)? = nil) -> Request {
        if let error = client.validate() {
            DispatchQueue.main.async {
                completionHandler?(.failure(error))
            }
            return LocalRequest()
        }

        let request = client.networkRequestFactory.buildUserLogin(username: username, password: password)
        Promise<U> { fulfill, reject in
            request.execute() { (data, response, error) in
                if let response = response, response.isOK, let user = client.responseParser.parseUser(data) as? U {
                    client.activeUser = user
                    fulfill(user)
                } else {
                    reject(buildError(data, response, error, client))
                }
            }
        }.then { user in
            completionHandler?(.success(user))
        }.catch { error in
            completionHandler?(.failure(error))
        }
        return request
    }
    
    /**
     Sends a request to confirm email address to the specified user.
     
     The user must have a valid email set in its `email` field, on the server, for this to work. The user will receive an email with a time-bound link to a verification web page.
     
     - parameter username: Username of the user that needs to send the email confirmation
     - parameter client: define the `Client` to be used for all the requests for the `DataStore` that will be returned. Default value: `Kinvey.sharedClient`
     - parameter completionHandler: Completion handler to be called once the response returns from the server
     */
    @discardableResult
    open class func sendEmailConfirmation(forUsername username: String, client: Client = Kinvey.sharedClient, completionHandler: ((Result<Void, Swift.Error>) -> Void)? = nil) -> Request {
        let request = client.networkRequestFactory.buildSendEmailConfirmation(forUsername: username)
        Promise<Void> { fulfill, reject in
            request.execute() { (data, response, error) in
                if let response = response, response.isOK {
                    fulfill(())
                } else {
                    reject(buildError(data, response, error, client))
                }
            }
        }.then { void in
            completionHandler?(.success(void))
        }.catch { error in
            completionHandler?(.failure(error))
        }
        return request
    }
    
    /**
     Sends a request to confirm email address to the user.
     
     The user must have a valid email set in its `email` field, on the server, for this to work. The user will receive an email with a time-bound link to a verification web page.
     
     - parameter client: define the `Client` to be used for all the requests for the `DataStore` that will be returned. Default value: `Kinvey.sharedClient`
     - parameter completionHandler: Completion handler to be called once the response returns from the server
     */
    @discardableResult
    open func sendEmailConfirmation(completionHandler: ((Result<Void, Swift.Error>) -> Void)? = nil) -> Request {
        guard let _ = email else {
            DispatchQueue.main.async {
                completionHandler?(.failure(Error.invalidOperation(description: "Email is required to send the email confirmation")))
            }
            return LocalRequest()
        }
        
        return User.sendEmailConfirmation(forUsername: username!, client: client, completionHandler: completionHandler)
    }
    
    /// Sends an email to the user with a link to reset the password
    @discardableResult
    private class func resetPassword(usernameOrEmail: String, client: Client = Kinvey.sharedClient, completionHandler: VoidHandler? = nil) -> Request {
        return resetPassword(
            usernameOrEmail: usernameOrEmail,
            client: client
        ) { (result: Result<Void, Swift.Error>) in
            switch result {
            case .success:
                completionHandler?(nil)
            case .failure(let error):
                completionHandler?(error)
            }
        }
    }
    
    /// Sends an email to the user with a link to reset the password
    @discardableResult
    open class func resetPassword(usernameOrEmail: String, client: Client = Kinvey.sharedClient, completionHandler: ((Result<Void, Swift.Error>) -> Void)? = nil) -> Request {
        let request = client.networkRequestFactory.buildUserResetPassword(usernameOrEmail: usernameOrEmail)
        Promise<Void> { fulfill, reject in
            request.execute() { (data, response, error) in
                if let response = response, response.isOK {
                    fulfill(())
                } else {
                    reject(buildError(data, response, error, client))
                }
            }
        }.then { void in
            completionHandler?(.success(void))
        }.catch { error in
            completionHandler?(.failure(error))
        }
        return request
    }
    
    /// Sends an email to the user with a link to reset the password using the `username` property.
    @discardableResult
    @available(*, deprecated: 3.3.4, message: "Use resetPassword(usernameOrEmail:) instead")
    open class func resetPassword(username: String, client: Client = Kinvey.sharedClient, completionHandler: VoidHandler? = nil) -> Request {
        return resetPassword(usernameOrEmail: username, client: client, completionHandler:  completionHandler)
    }
    
    /// Sends an email to the user with a link to reset the password using the `email` property.
    @discardableResult
    @available(*, deprecated: 3.3.4, message: "Use resetPassword(usernameOrEmail:) instead")
    open class func resetPassword(email: String, client: Client = Kinvey.sharedClient, completionHandler: VoidHandler? = nil) -> Request {
        return resetPassword(usernameOrEmail: email, client: client, completionHandler:  completionHandler)
    }
    
    /// Sends an email to the user with a link to reset the password.
    @discardableResult
    open func resetPassword(completionHandler: ((Result<Void, Swift.Error>) -> Void)? = nil) -> Request {
        if let email = email {
            return User.resetPassword(usernameOrEmail: email, client: client, completionHandler: completionHandler)
        } else if let username = username  {
            return User.resetPassword(usernameOrEmail: username, client: client, completionHandler: completionHandler)
        } else if let completionHandler = completionHandler {
            DispatchQueue.main.async(execute: { () -> Void in
                completionHandler(.failure(Error.userWithoutEmailOrUsername))
            })
        }
        return LocalRequest()
    }
    
    /**
     Changes the password for the current user and automatically updates the session with a new valid session.
     - parameter newPassword: A new password for the user
     - parameter client: Define the `Client` to be used for all the requests for the `DataStore` that will be returned. Default value: `Kinvey.sharedClient`
     - parameter completionHandler: Completion handler to be called once the response returns from the server
     */
    @discardableResult
    open func changePassword<U: User>(newPassword: String, completionHandler: UserHandler<U>? = nil) -> Request {
        return changePassword(
            newPassword: newPassword
        ) { (result: Result<U, Swift.Error>) in
            switch result {
            case .success(let user):
                completionHandler?(user, nil)
            case .failure(let error):
                completionHandler?(nil, error)
            }
        }
    }
    
    /**
     Changes the password for the current user and automatically updates the session with a new valid session.
     - parameter newPassword: A new password for the user
     - parameter client: Define the `Client` to be used for all the requests for the `DataStore` that will be returned. Default value: `Kinvey.sharedClient`
     - parameter completionHandler: Completion handler to be called once the response returns from the server
     */
    @discardableResult
    open func changePassword<U: User>(newPassword: String, completionHandler: ((Result<U, Swift.Error>) -> Void)? = nil) -> Request {
        return save(newPassword: newPassword, completionHandler: completionHandler)
    }
    
    /**
     Sends an email with the username associated with the email provided.
     - parameter email: Email associated with the user
     - parameter client: Define the `Client` to be used for all the requests for the `DataStore` that will be returned. Default value: `Kinvey.sharedClient`
     - parameter completionHandler: Completion handler to be called once the response returns from the server
     */
    @discardableResult
    open class func forgotUsername(email: String, client: Client = Kinvey.sharedClient, completionHandler: ((Result<Void, Swift.Error>) -> Void)? = nil) -> Request {
        let request = client.networkRequestFactory.buildUserForgotUsername(email: email)
        Promise<Void> { fulfill, reject in
            request.execute() { (data, response, error) in
                if let response = response, response.isOK {
                    fulfill(())
                } else {
                    reject(buildError(data, response, error, client))
                }
            }
        }.then { void in
            completionHandler?(.success(void))
        }.catch { error in
            completionHandler?(.failure(error))
        }
        return request
    }
    
    /// Checks if a `username` already exists or not.
    @discardableResult
    open class func exists(username: String, client: Client = Kinvey.sharedClient, completionHandler: BoolHandler? = nil) -> Request {
        return exists(
            username: username,
            client: client
        ) { (result: Result<Bool, Swift.Error>) in
            switch result {
            case .success(let exists):
                completionHandler?(exists, nil)
            case .failure(let error):
                completionHandler?(false, error)
            }
        }
    }
    
    /// Checks if a `username` already exists or not.
    @discardableResult
    open class func exists(username: String, client: Client = Kinvey.sharedClient, completionHandler: ((Result<Bool, Swift.Error>) -> Void)? = nil) -> Request {
        let request = client.networkRequestFactory.buildUserExists(username: username)
        Promise<Bool> { fulfill, reject in
            request.execute() { (data, response, error) in
                if let response = response, response.isOK, let json = client.responseParser.parse(data), let usernameExists = json["usernameExists"] as? Bool {
                    fulfill(usernameExists)
                } else {
                    reject(buildError(data, response, error, client))
                }
            }
        }.then { exists in
            completionHandler?(.success(exists))
        }.catch { error in
            completionHandler?(.failure(error))
        }
        return request
    }
    
    /// Gets a `User` instance using the `userId` property.
    @discardableResult
    open class func get<U: User>(userId: String, client: Client = Kinvey.sharedClient, completionHandler: UserHandler<U>? = nil) -> Request {
        return get(
            userId: userId,
            client: client
        ) { (result: Result<U, Swift.Error>) in
            switch result {
            case .success(let user):
                completionHandler?(user, nil)
            case .failure(let error):
                completionHandler?(nil, error)
            }
        }
    }
    
    /// Gets a `User` instance using the `userId` property.
    @discardableResult
    open class func get<U: User>(userId: String, client: Client = Kinvey.sharedClient, completionHandler: ((Result<U, Swift.Error>) -> Void)? = nil) -> Request {
        let request = client.networkRequestFactory.buildUserGet(userId: userId)
        Promise<U> { fulfill, reject in
            request.execute() { (data, response, error) in
                if let response = response, response.isOK, let user = client.responseParser.parseUser(data) as? U {
                    fulfill(user)
                } else {
                    reject(buildError(data, response, error, client))
                }
            }
        }.then { user in
            completionHandler?(.success(user))
        }.catch { error in
            completionHandler?(.failure(error))
        }
        return request
    }
    
    /// Gets a `User` instance using the `userId` property.
    @discardableResult
    open func find<U: User>(query: Query = Query(), client: Client = sharedClient, completionHandler: ((Result<[U], Swift.Error>) -> Void)? = nil) -> Request {
        let request = client.networkRequestFactory.buildUserFind(query: query)
        Promise<[U]> { fulfill, reject in
            request.execute() { (data, response, error) in
                if let response = response, response.isOK, let user = client.responseParser.parseUsers(data) as? [U] {
                    fulfill(user)
                } else {
                    reject(buildError(data, response, error, client))
                }
            }
        }.then { users in
            completionHandler?(.success(users))
        }.catch { error in
            completionHandler?(.failure(error))
        }
        return request
    }
    
    /// Refresh the user's data.
    @discardableResult
    open func refresh(completionHandler: ((Result<Void, Swift.Error>) -> Void)? = nil) -> Request {
        let request = client.networkRequestFactory.buildUserMe()
        Promise<Void> { fulfill, reject in
            request.execute() { (data, response, error) in
                if let response = response, response.isOK, let json = self.client.responseParser.parse(data) {
                    let map = Map(mappingType: .fromJSON, JSON: json)
                    self.mapping(map: map)
                    if self == self.client.activeUser {
                        self.client.activeUser = self
                    }
                    fulfill(())
                } else {
                    reject(buildError(data, response, error, self.client))
                }
            }
        }.then { void in
            completionHandler?(.success(void))
        }.catch { error in
            completionHandler?(.failure(error))
        }
        return request
    }
    
    /// Default Constructor.
    public init(userId: String? = nil, acl: Acl? = nil, metadata: UserMetadata? = nil, client: Client = Kinvey.sharedClient) {
        self._userId = userId
        self.acl = acl
        self.metadata = metadata
        self.client = client
    }
    
    /// Constructor that validates if the map contains at least the `userId`.
    public required convenience init?(map: Map) {
        var userId: String?
        var acl: Acl?
        var metadata: UserMetadata?
        
        userId <- map[Entity.Key.entityId]
        guard let userIdValue = userId else {
            return nil
        }
        
        acl <- map[Entity.Key.acl]
        metadata <- map[Entity.Key.metadata]
        self.init(userId: userIdValue, acl: acl, metadata: metadata)
    }
    
    /// This function is where all variable mappings should occur. It is executed by Mapper during the mapping (serialization and deserialization) process.
    open func mapping(map: Map) {
        _userId <- map[Entity.Key.entityId]
        acl <- map[Entity.Key.acl]
        metadata <- map[Entity.Key.metadata]
        socialIdentity <- map["_socialIdentity"]
        username <- map["username"]
        email <- map["email"]
    }
    
    /// Sign out the current active user.
    open func logout() {
        if self == client.activeUser {
            client.activeUser = nil
        }
    }
    
    /// Creates or updates a `User`.
    @discardableResult
    open func save<U: User>(newPassword: String? = nil, completionHandler: UserHandler<U>? = nil) -> Request {
        return save(
            newPassword: newPassword
        ) { (result: Result<U, Swift.Error>) in
            switch result {
            case .success(let user):
                completionHandler?(user, nil)
            case .failure(let error):
                completionHandler?(nil, error)
            }
        }
    }
    
    /// Creates or updates a `User`.
    @discardableResult
    open func save<U: User>(newPassword: String? = nil, completionHandler: ((Result<U, Swift.Error>) -> Void)? = nil) -> Request {
        let request = client.networkRequestFactory.buildUserSave(user: self, newPassword: newPassword)
        Promise<U> { fulfill, reject in
            request.execute() { (data, response, error) in
                if let response = response, response.isOK, let user = self.client.responseParser.parseUser(data) as? U {
                    if user.userId == self.client.activeUser?.userId {
                        self.client.activeUser = user
                    }
                    fulfill(user)
                } else {
                    reject(buildError(data, response, error, self.client))
                }
            }
        }.then { user in
            completionHandler?(.success(user))
        }.catch { error in
            completionHandler?(.failure(error))
        }
        return request
    }
    
    /**
     This method allows users to do exact queries for other users restricted to the `UserQuery` attributes.
     */
    @discardableResult
    open func lookup<U: User>(_ userQuery: UserQuery, completionHandler: UsersHandler<U>? = nil) -> Request {
        return lookup(userQuery) { (result: Result<[U], Swift.Error>) in
            switch result {
            case .success(let users):
                completionHandler?(users, nil)
            case .failure(let error):
                completionHandler?(nil, error)
            }
        }
    }
    
    /**
     This method allows users to do exact queries for other users restricted to the `UserQuery` attributes.
     */
    @discardableResult
    open func lookup<U: User>(_ userQuery: UserQuery, completionHandler: ((Result<[U], Swift.Error>) -> Void)? = nil) -> Request {
        let request = client.networkRequestFactory.buildUserLookup(user: self, userQuery: userQuery)
        Promise<[U]> { fulfill, reject in
            request.execute() { (data, response, error) in
                if let response = response, response.isOK, let users: [U] = self.client.responseParser.parseUsers(data) {
                    fulfill(users)
                } else {
                    reject(buildError(data, response, error, self.client))
                }
            }
        }.then { users in
            completionHandler?(.success(users))
        }.catch { error in
            completionHandler?(.failure(error))
        }
        return request
    }
    
    @discardableResult
    open func registerForRealtime(completionHandler: ((Result<Void, Swift.Error>) -> Void)? = nil) -> Request {
        let request = client.networkRequestFactory.buildUserRegisterRealtime(user: self, deviceId: deviceId)
        Promise<Void> { fulfill, reject in
            request.execute() { (data, response, error) in
                if let response = response,
                    response.isOK,
                    let data = data,
                    let json = self.client.responseParser.parse(data),
                    let subscribeKey = json["subscribeKey"] as? String,
                    let publishKey = json["publishKey"] as? String,
                    let userChannelGroup = json["userChannelGroup"] as? String
                {
                    self.realtimeRouter = PubNubRealtimeRouter(user: self, subscribeKey: subscribeKey, publishKey: publishKey, userChannelGroup: userChannelGroup)
                    fulfill(())
                } else {
                    reject(buildError(data, response, error, self.client))
                }
            }
        }.then { void in
            completionHandler?(.success(void))
        }.catch { error in
            completionHandler?(.failure(error))
        }
        return request
    }
    
    @discardableResult
    open func unregisterForRealtime(completionHandler: ((Result<Void, Swift.Error>) -> Void)? = nil) -> Request {
        let request = client.networkRequestFactory.buildUserUnregisterRealtime(user: self, deviceId: deviceId)
        Promise<Void> { fulfill, reject in
            request.execute() { (data, response, error) in
                if let response = response, response.isOK {
                    self.realtimeRouter = nil
                    fulfill(())
                } else {
                    reject(buildError(data, response, error, self.client))
                }
            }
        }.then { void in
            completionHandler?(.success(void))
        }.catch { error in
            completionHandler?(.failure(error))
        }
        return request
    }
    
    internal static let authtokenPrefix = "Kinvey "
    
    /// Autorization header used for calls that requires a logged `User`.
    open var authorizationHeader: String? {
        var authorization: String? = nil
        if let authtoken = metadata?.authtoken {
            authorization = "Kinvey \(authtoken)"
        }
        return authorization
    }
    
    /**
     Login with MIC using Automated Authorization Grant Flow. We strongly recommend use [Authorization Code Grant Flow](http://devcenter.kinvey.com/rest/guides/mobile-identity-connect#authorization-grant) instead of [Automated Authorization Grant Flow](http://devcenter.kinvey.com/rest/guides/mobile-identity-connect#automated-authorization-grant) for security reasons.
     */
    open class func login<U: User>(
        redirectURI: URL,
        username: String,
        password: String,
        clientId: String? = nil,
        client: Client = sharedClient,
        completionHandler: UserHandler<U>? = nil
    ) {
        return login(
            redirectURI: redirectURI,
            username: username,
            password: password,
            clientId: clientId,
            client: client
        ) { (result: Result<U, Swift.Error>) in
            switch result {
            case .success(let user):
                completionHandler?(user, nil)
            case .failure(let error):
                completionHandler?(nil, error)
            }
        }
    }
    
    /**
     Login with MIC using Automated Authorization Grant Flow. We strongly recommend use [Authorization Code Grant Flow](http://devcenter.kinvey.com/rest/guides/mobile-identity-connect#authorization-grant) instead of [Automated Authorization Grant Flow](http://devcenter.kinvey.com/rest/guides/mobile-identity-connect#automated-authorization-grant) for security reasons.
     */
    open class func login<U: User>(
        redirectURI: URL,
        username: String,
        password: String,
        clientId: String? = nil,
        client: Client = sharedClient,
        completionHandler: ((Result<U, Swift.Error>) -> Void)? = nil
    ) {
        MIC.login(
            redirectURI: redirectURI,
            username: username,
            password: password,
            clientId: clientId,
            client: client,
            completionHandler: completionHandler
        )
    }

#if os(iOS)
    
    static let MICSafariViewControllerSuccessNotificationName = NSNotification.Name("Kinvey.User.MICSafariViewController.Success")
    static let MICSafariViewControllerFailureNotificationName = NSNotification.Name("Kinvey.User.MICSafariViewController.Failure")
    
    private static var MICSafariViewControllerSuccessNotificationObserver: Any? = nil {
        willSet {
            if let token = MICSafariViewControllerSuccessNotificationObserver {
                NotificationCenter.default.removeObserver(token, name: MICSafariViewControllerSuccessNotificationName, object: nil)
                NotificationCenter.default.removeObserver(token, name: MICSafariViewControllerFailureNotificationName, object: nil)
            }
        }
    }
    
    private static var MICSafariViewControllerFailureNotificationObserver: Any? = nil {
        willSet {
            if let token = MICSafariViewControllerFailureNotificationObserver {
                NotificationCenter.default.removeObserver(token, name: MICSafariViewControllerSuccessNotificationName, object: nil)
                NotificationCenter.default.removeObserver(token, name: MICSafariViewControllerFailureNotificationName, object: nil)
            }
        }
    }
    
    /// Performs a login using the MIC Redirect URL that contains a temporary token.
    open class func login(redirectURI: URL, micURL: URL, clientId: String? = nil, client: Client = sharedClient) -> Bool {
        if let code = MIC.parseCode(redirectURI: redirectURI, url: micURL) {
            MIC.login(redirectURI: redirectURI, code: code, clientId: clientId, client: client) { result in
                switch result {
                case .success(let user):
                    NotificationCenter.default.post(
                        name: MICSafariViewControllerSuccessNotificationName,
                        object: user
                    )
                case .failure(let error):
                    NotificationCenter.default.post(
                        name: MICSafariViewControllerFailureNotificationName,
                        object: error
                    )
                }
            }
            return true
        }
        return false
    }

    /// Presents the MIC View Controller to sign in a user using MIC (Mobile Identity Connect).
    @available(*, deprecated: 3.3.2, message: "Please use the method presentMICViewController(micUserInterface:) instead")
    open class func presentMICViewController(
        redirectURI: URL,
        timeout: TimeInterval = 0,
        forceUIWebView: Bool,
        clientId: String? = nil,
        client: Client = sharedClient,
        completionHandler: UserHandler<User>? = nil
    ) {
        presentMICViewController(
            redirectURI: redirectURI,
            timeout: timeout,
            micUserInterface: forceUIWebView ? .uiWebView : .wkWebView,
            clientId: clientId,
            client: client,
            completionHandler: completionHandler
        )
    }
    
    /// Presents the MIC View Controller to sign in a user using MIC (Mobile Identity Connect).
    open class func presentMICViewController<U: User>(
        redirectURI: URL,
        timeout: TimeInterval = 0,
        micUserInterface: MICUserInterface = .safari,
        currentViewController: UIViewController? = nil,
        clientId: String? = nil,
        client: Client = sharedClient,
        completionHandler: UserHandler<U>? = nil
    ) {
        presentMICViewController(
            redirectURI: redirectURI,
            timeout: timeout,
            micUserInterface: micUserInterface,
            currentViewController: currentViewController,
            clientId: clientId,
            client: client
        ) { (result: Result<U, Swift.Error>) in
            switch result {
            case .success(let user):
                completionHandler?(user, nil)
            case .failure(let error):
                completionHandler?(nil, error)
            }
        }
    }
    
    /// Presents the MIC View Controller to sign in a user using MIC (Mobile Identity Connect).
    open class func presentMICViewController<U: User>(
        redirectURI: URL,
        timeout: TimeInterval = 0,
        micUserInterface: MICUserInterface = .safari,
        currentViewController: UIViewController? = nil,
        clientId: String? = nil,
        client: Client = sharedClient,
        completionHandler: ((Result<U, Swift.Error>) -> Void)? = nil
    ) {
        if let error = client.validate() {
            DispatchQueue.main.async {
                completionHandler?(.failure(error))
            }
            return
        }
        
        Promise<U> { fulfill, reject in
            var micVC: UIViewController!
            
            switch micUserInterface {
            case .safari:
                let url = MIC.urlForLogin(redirectURI: redirectURI, clientId: clientId, client: client)
                micVC = SFSafariViewController(url: url)
                micVC.modalPresentationStyle = .overCurrentContext
                MICSafariViewControllerSuccessNotificationObserver = NotificationCenter.default.addObserver(
                    forName: MICSafariViewControllerSuccessNotificationName,
                    object: nil,
                    queue: OperationQueue.main)
                { notification in
                    micVC.dismiss(animated: true) {
                        MICSafariViewControllerSuccessNotificationObserver = nil
                        
                        if let user = notification.object as? U {
                            fulfill(user)
                        } else {
                            reject(Error.invalidResponse(httpResponse: nil, data: nil))
                        }
                    }
                }
                MICSafariViewControllerFailureNotificationObserver = NotificationCenter.default.addObserver(
                    forName: MICSafariViewControllerFailureNotificationName,
                    object: nil,
                    queue: OperationQueue.main)
                { notification in
                    micVC.dismiss(animated: true) {
                        MICSafariViewControllerFailureNotificationObserver = nil
                        
                        if let error = notification.object as? Swift.Error {
                            reject(error)
                        } else {
                            reject(Error.invalidResponse(httpResponse: nil, data: nil))
                        }
                    }
                }
            default:
                let forceUIWebView = micUserInterface == .uiWebView
                let micLoginVC = MICLoginViewController(
                    redirectURI: redirectURI,
                    userType: client.userType,
                    timeout: timeout,
                    forceUIWebView: forceUIWebView,
                    clientId: clientId,
                    client: client
                ) { (result) in
                    switch result {
                    case .success(let user):
                        fulfill(user as! U)
                    case .failure(let error):
                        reject(error)
                    }
                }
                micVC = UINavigationController(rootViewController: micLoginVC)
            }
            
            var viewController = currentViewController
            if viewController == nil {
                viewController = UIApplication.shared.keyWindow?.rootViewController
                if let presentedViewController =  viewController?.presentedViewController {
                    viewController = presentedViewController
                }
            }
            viewController?.present(micVC, animated: true)
        }.then { user -> Void in
            completionHandler?(.success(user))
        }.catch { error in
            completionHandler?(.failure(error))
        }
    }
#endif

}

public struct UserSocialIdentity : StaticMappable {
    
    /// Facebook social identity
    public let facebook: [String : Any]?
    
    /// Twitter social identity
    public let twitter: [String : Any]?
    
    /// Google+ social identity
    public let googlePlus: [String : Any]?
    
    /// LinkedIn social identity
    public let linkedIn: [String : Any]?
    
    /// Kinvey MIC social identity
    public let kinvey: [String : Any]?
    
    public static func objectForMapping(map: Map) -> BaseMappable? {
        return UserSocialIdentity(
            facebook: map[AuthSource.facebook.rawValue].value(),
            twitter: map[AuthSource.twitter.rawValue].value(),
            googlePlus: map[AuthSource.googlePlus.rawValue].value(),
            linkedIn: map[AuthSource.linkedIn.rawValue].value(),
            kinvey: map[AuthSource.kinvey.rawValue].value()
        )
    }
    
    public mutating func mapping(map: Map) {
    }
    
}
