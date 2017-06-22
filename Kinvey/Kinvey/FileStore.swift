//
//  FileStore.swift
//  Kinvey
//
//  Created by Victor Barros on 2016-02-04.
//  Copyright © 2016 Kinvey. All rights reserved.
//

import Foundation
import PromiseKit
import ObjectMapper


#if os(macOS)
    import AppKit
#else
    import UIKit
#endif

public enum ImageRepresentation {
    
    case png
    case jpeg(compressionQuality: Float)

#if os(macOS)
    
    func data(image: NSImage) -> Data? {
        guard let cgImage = image.cgImage(forProposedRect: nil, context: nil, hints: nil) else {
            return nil
        }
        let newRep = NSBitmapImageRep(cgImage: cgImage)
        newRep.size = image.size
        var fileType: NSBitmapImageFileType!
        var properties: [String : Any]!
        switch self {
        case .png:
            fileType = NSPNGFileType
            properties = [:]
        case .jpeg(let compressionQuality):
            fileType = NSJPEGFileType
            properties = [NSImageCompressionFactor : compressionQuality]
        }
        return newRep.representation(using: fileType, properties: properties)
    }
    
#else

    func data(image: UIImage) -> Data? {
        switch self {
        case .png:
            return UIImagePNGRepresentation(image)
        case .jpeg(let compressionQuality):
            return UIImageJPEGRepresentation(image, CGFloat(compressionQuality))
        }
    }
    
#endif
    
    var mimeType: String {
        switch self {
        case .png: return "image/png"
        case .jpeg: return "image/jpeg"
        }
    }
    
}

/// Class to interact with the `Files` collection in the backend.
open class FileStore<FileType: File> {
    
    public typealias FileCompletionHandler = (FileType?, Swift.Error?) -> Void
    public typealias FileDataCompletionHandler = (FileType?, Data?, Swift.Error?) -> Void
    public typealias FilePathCompletionHandler = (FileType?, URL?, Swift.Error?) -> Void
    public typealias UIntCompletionHandler = (UInt?, Swift.Error?) -> Void
    public typealias FileArrayCompletionHandler = ([FileType]?, Swift.Error?) -> Void
    
    internal let client: Client
    internal let cache: AnyFileCache<FileType>?
    
    /// Factory method that returns a `FileStore`.
    @available(*, deprecated: 3.5.2, message: "Please use the constructor instead")
    open class func getInstance<FileType: File>(client: Client = sharedClient) -> FileStore<FileType> {
        return FileStore<FileType>(client: client)
    }
    
    /// Factory method that returns a `FileStore`.
    @available(*, deprecated: 3.5.2, message: "Please use the constructor instead")
    open class func getInstance<FileType: File>(fileType: FileType.Type, client: Client = sharedClient) -> FileStore<FileType> {
        return FileStore<FileType>(client: client)
    }
    
    public init(client: Client = sharedClient) {
        self.client = client
        self.cache = client.cacheManager.fileCache(fileURL: client.fileURL())
    }

#if os(macOS)
    
    /// Uploads a `UIImage` in a PNG or JPEG format.
    @discardableResult
    open func upload(_ file: FileType, image: NSImage, imageRepresentation: ImageRepresentation = .png, ttl: TTL? = nil, completionHandler: FileCompletionHandler? = nil) -> Request {
        return upload(
            file,
            image: image,
            imageRepresentation: imageRepresentation,
            ttl: ttl
        ) { (result: Result<FileType, Swift.Error>) in
            switch result {
            case .success(let file):
                completionHandler?(file, nil)
            case .failure(let error):
                completionHandler?(nil, error)
            }
        }
    }
    
    /// Uploads a `UIImage` in a PNG or JPEG format.
    @discardableResult
    open func upload(_ file: FileType, image: NSImage, imageRepresentation: ImageRepresentation = .png, ttl: TTL? = nil, completionHandler: ((Result<FileType, Swift.Error>) -> Void)? = nil) -> Request {
        let data = imageRepresentation.data(image: image)!
        file.mimeType = imageRepresentation.mimeType
        return upload(file, data: data, ttl: ttl, completionHandler: completionHandler)
    }
    
#else

    /// Uploads a `UIImage` in a PNG or JPEG format.
    @discardableResult
    open func upload(_ file: FileType, image: UIImage, imageRepresentation: ImageRepresentation = .png, ttl: TTL? = nil, completionHandler: FileCompletionHandler? = nil) -> Request {
        return upload(
            file,
            image: image,
            imageRepresentation: imageRepresentation,
            ttl: ttl
        ) { (result: Result<FileType, Swift.Error>) in
            switch result {
            case .success(let file):
                completionHandler?(file, nil)
            case .failure(let error):
                completionHandler?(nil, error)
            }
        }
    }
    
    /// Uploads a `UIImage` in a PNG or JPEG format.
    @discardableResult
    open func upload(_ file: FileType, image: UIImage, imageRepresentation: ImageRepresentation = .png, ttl: TTL? = nil, completionHandler: ((Result<FileType, Swift.Error>) -> Void)? = nil) -> Request {
        let data = imageRepresentation.data(image: image)!
        file.mimeType = imageRepresentation.mimeType
        return upload(file, data: data, ttl: ttl, completionHandler: completionHandler)
    }

#endif
    
    /// Uploads a file using the file path.
    @discardableResult
    open func upload(_ file: FileType, path: String, ttl: TTL? = nil, completionHandler: FileCompletionHandler? = nil) -> Request {
        return upload(
            file,
            path: path,
            ttl: ttl
        ) { (result: Result<FileType, Swift.Error>) in
            switch result {
            case .success(let file):
                completionHandler?(file, nil)
            case .failure(let error):
                completionHandler?(nil, error)
            }
        }
    }
    
    /// Uploads a file using the file path.
    @discardableResult
    open func upload(_ file: FileType, path: String, ttl: TTL? = nil, completionHandler: ((Result<FileType, Swift.Error>) -> Void)? = nil) -> Request {
        return upload(file, fromSource: .url(URL(fileURLWithPath: path)), ttl: ttl, completionHandler: completionHandler)
    }
    
    /// Uploads a file using a input stream.
    @discardableResult
    open func upload(_ file: FileType, stream: InputStream, ttl: TTL? = nil, completionHandler: FileCompletionHandler? = nil) -> Request {
        return upload(
            file,
            stream: stream,
            ttl: ttl
        ) { (result: Result<FileType, Swift.Error>) in
            switch result {
            case .success(let file):
                completionHandler?(file, nil)
            case .failure(let error):
                completionHandler?(nil, error)
            }
        }
    }
    
    /// Uploads a file using a input stream.
    @discardableResult
    open func upload(_ file: FileType, stream: InputStream, ttl: TTL? = nil, completionHandler: ((Result<FileType, Swift.Error>) -> Void)? = nil) -> Request {
        return upload(file, fromSource: .stream(stream), ttl: ttl, completionHandler: completionHandler)
    }

    fileprivate func getFileMetadata(_ file: FileType, ttl: TTL? = nil) -> (request: Request, promise: Promise<FileType>) {
        let request = self.client.networkRequestFactory.buildBlobDownloadFile(file, ttl: ttl)
        let promise = Promise<FileType> { fulfill, reject in
            request.execute() { (data, response, error) -> Void in
                if let response = response, response.isOK,
                    let json = self.client.responseParser.parse(data),
                    let newFile = FileType(JSON: json) {
                    newFile.path = file.path
                    if let cache = self.cache {
                        cache.save(newFile, beforeSave: nil)
                    }
                    
                    fulfill(newFile)
                } else {
                    reject(buildError(data, response, error, self.client))
                }
            }
        }
        return (request: request, promise: promise)
    }
    
    /// Uploads a file using a `NSData`.
    @discardableResult
    open func upload(_ file: FileType, data: Data, ttl: TTL? = nil, completionHandler: FileCompletionHandler? = nil) -> Request {
        return upload(
            file,
            data: data,
            ttl: ttl
        ) { (result: Result<FileType, Swift.Error>) in
            switch result {
            case .success(let file):
                completionHandler?(file, nil)
            case .failure(let error):
                completionHandler?(nil, error)
            }
        }
    }
    
    /// Uploads a file using a `NSData`.
    @discardableResult
    open func upload(_ file: FileType, data: Data, ttl: TTL? = nil, completionHandler: ((Result<FileType, Swift.Error>) -> Void)? = nil) -> Request {
        return upload(file, fromSource: .data(data), ttl: ttl, completionHandler: completionHandler)
    }
    
    fileprivate enum InputSource {
        
        case data(Data)
        case url(URL)
        case stream(InputStream)
        
    }
    
    /// Uploads a file using a `NSData`.
    fileprivate func upload(_ file: FileType, fromSource source: InputSource, ttl: TTL? = nil, completionHandler: ((Result<FileType, Swift.Error>) -> Void)? = nil) -> Request {
        if file.size.value == nil {
            switch source {
            case let .data(data):
                file.size.value = Int64(data.count)
            case let .url(url):
                if let attrs = try? FileManager.default.attributesOfItem(atPath: url.path),
                    let fileSize = attrs[.size] as? Int64
                {
                    file.size.value = fileSize
                }
            default:
                break
            }
        }
        let requests = MultiRequest()
        Promise<(file: FileType, skip: Int?)> { fulfill, reject in //creating bucket
            let createUpdateFileEntry = {
                let request = self.client.networkRequestFactory.buildBlobUploadFile(file)
                requests += request
                request.execute { (data, response, error) -> Void in
                    if let response = response, response.isOK,
                        let json = self.client.responseParser.parse(data),
                        let newFile = FileType(JSON: json)
                    {
                        fulfill((file: newFile, skip: nil))
                    } else {
                        reject(buildError(data, response, error, self.client))
                    }
                }
            }
            
            if let _ = file.fileId,
                let uploadURL = file.uploadURL
            {
                var request = URLRequest(url: uploadURL)
                request.httpMethod = "PUT"
                if let uploadHeaders = file.uploadHeaders {
                    for (headerField, value) in uploadHeaders {
                        request.setValue(value, forHTTPHeaderField: headerField)
                    }
                }
                request.setValue("0", forHTTPHeaderField: "Content-Length")
                switch source {
                case let .data(data):
                    request.setValue("bytes */\(data.count)", forHTTPHeaderField: "Content-Range")
                case let .url(url):
                    if let attrs = try? FileManager.default.attributesOfItem(atPath: (url.path as NSString).expandingTildeInPath),
                        let fileSize = attrs[FileAttributeKey.size] as? UInt64
                    {
                        request.setValue("bytes */\(fileSize)", forHTTPHeaderField: "Content-Range")
                    }
                case .stream:
                    request.setValue("bytes */*", forHTTPHeaderField: "Content-Range")
                    break
                }
                
                if self.client.logNetworkEnabled {
                    do {
                        log.debug("\(request)")
                    }
                }
                
                let dataTask = self.client.urlSession.dataTask(with: request) { (data, response, error) in
                    if self.client.logNetworkEnabled, let response = response as? HTTPURLResponse {
                        do {
                            log.debug("\(response.description(data))")
                        }
                    }
                    
                    let regexRange = try! NSRegularExpression(pattern: "[bytes=]?(\\d+)-(\\d+)")
                    if let response = response as? HTTPURLResponse, 200 <= response.statusCode && response.statusCode < 300 {
                        createUpdateFileEntry()
                    } else if let response = response as? HTTPURLResponse,
                        response.statusCode == 308,
                        let rangeString = response.allHeaderFields["Range"] as? String,
                        let textCheckingResult = regexRange.matches(in: rangeString, range: NSMakeRange(0, rangeString.characters.count)).first,
                        textCheckingResult.numberOfRanges == 3
                    {
                        let rangeNSString = rangeString as NSString
                        let endRangeString = rangeNSString.substring(with: textCheckingResult.range(at: 2))
                        if let endRange = Int(endRangeString) {
                            fulfill((file: file, skip: endRange))
                        } else {
                            reject(Error.invalidResponse(httpResponse: response, data: data))
                        }
                    } else {
                        reject(buildError(data, HttpResponse(response: response), error, self.client))
                    }
                }
                requests += URLSessionTaskRequest(client: client, task: dataTask)
                dataTask.resume()
            } else {
                createUpdateFileEntry()
            }
        }.then { arg -> Promise<FileType> in //uploading data
            let (file, skip) = arg
            return Promise<FileType> { fulfill, reject in
                var request = URLRequest(url: file.uploadURL!)
                request.httpMethod = "PUT"
                if let uploadHeaders = file.uploadHeaders {
                    for (headerField, value) in uploadHeaders {
                        request.setValue(value, forHTTPHeaderField: headerField)
                    }
                }
                
                let handler: (Data?, URLResponse?, Swift.Error?) -> Void = { data, response, error in
                    if self.client.logNetworkEnabled, let response = response as? HTTPURLResponse {
                        do {
                            log.debug("\(response.description(data))")
                        }
                    }
                    
                    if let response = response as? HTTPURLResponse, 200 <= response.statusCode && response.statusCode < 300 {
                        switch source {
                        case let .url(url):
                            file.path = url.path
                        default:
                            break
                        }
                        
                        fulfill(file)
                    } else {
                        reject(buildError(data, HttpResponse(response: response), error, self.client))
                    }
                }
                
                switch source {
                case let .data(data):
                    let uploadData: Data
                    if let skip = skip {
                        let startIndex = skip + 1
                        uploadData = data.subdata(in: startIndex ..< data.count - startIndex)
                        request.setValue("bytes \(startIndex)-\(data.count - 1)/\(data.count)", forHTTPHeaderField: "Content-Range")
                    } else {
                        uploadData = data
                    }
                    
                    if self.client.logNetworkEnabled {
                        do {
                            log.debug("\(request.description)")
                        }
                    }
                    
                    let uploadTask = self.client.urlSession.uploadTask(with: request, from: uploadData) { (data, response, error) -> Void in
                        handler(data, response, error)
                    }
                    requests += (URLSessionTaskRequest(client: self.client, task: uploadTask), addProgress: true)
                    uploadTask.resume()
                case let .url(url):
                    if self.client.logNetworkEnabled {
                        do {
                            log.debug("\(request.description)")
                        }
                    }
                    
                    let uploadTask = self.client.urlSession.uploadTask(with: request, fromFile: url) { (data, response, error) -> Void in
                        handler(data, response, error)
                    }
                    requests += (URLSessionTaskRequest(client: self.client, task: uploadTask), addProgress: true)
                    uploadTask.resume()
                case let .stream(stream):
                    request.httpBodyStream = stream
                    
                    if self.client.logNetworkEnabled {
                        do {
                            log.debug("\(request.description)")
                        }
                    }
                    
                    let dataTask = self.client.urlSession.dataTask(with: request) { (data, response, error) -> Void in
                        handler(data, response, error)
                    }
                    requests += (URLSessionTaskRequest(client: self.client, task: dataTask), addProgress: true)
                    dataTask.resume()
                }
            }
        }.then { file in //fetching download url
            let (request, promise) = self.getFileMetadata(file, ttl: ttl)
            requests += request
            return promise
        }.then { file in
            completionHandler?(.success(file))
        }.catch { error in
            completionHandler?(.failure(error))
        }
        return requests
    }
    
    /// Refresh a `File` instance.
    @discardableResult
    open func refresh(_ file: FileType, ttl: TTL? = nil, completionHandler: FileCompletionHandler? = nil) -> Request {
        return refresh(
            file,
            ttl: ttl
        ) { (result: Result<FileType, Swift.Error>) in
            switch result {
            case .success(let file):
                completionHandler?(file, nil)
            case .failure(let error):
                completionHandler?(nil, error)
            }
        }
    }
    
    /// Refresh a `File` instance.
    @discardableResult
    open func refresh(_ file: FileType, ttl: TTL? = nil, completionHandler: ((Result<FileType, Swift.Error>) -> Void)? = nil) -> Request {
        let (request, promise) = getFileMetadata(file, ttl: ttl)
        promise.then { file in
            completionHandler?(.success(file))
        }.catch { error in
            completionHandler?(.failure(error))
        }
        return request
    }
    
    @discardableResult
    fileprivate func downloadFileURL(_ file: FileType, storeType: StoreType = .cache, downloadURL: URL) -> (request: URLSessionTaskRequest, promise: Promise<URL>) {
        let downloadTaskRequest = URLSessionTaskRequest(client: client, url: downloadURL)
        let promise = Promise<URL> { fulfill, reject in
            let executor = Executor()
            downloadTaskRequest.downloadTaskWithURL(file) { (url: URL?, response, error) in
                if let response = response, response.isOK || response.isNotModified, let url = url {
                    if storeType == .cache {
                        var pathURL: URL? = nil
                        var entityId: String? = nil
                        executor.executeAndWait {
                            entityId = file.fileId
                            pathURL = file.pathURL
                        }
                        if let pathURL = pathURL, response.isNotModified {
                            fulfill(pathURL)
                        } else {
                            let fileManager = FileManager()
                            if let entityId = entityId,
                                let baseFolder = NSSearchPathForDirectoriesInDomains(.documentDirectory, .userDomainMask, true).first
                            {
                                do {
                                    var baseFolderURL = URL(fileURLWithPath: baseFolder)
                                    baseFolderURL = baseFolderURL.appendingPathComponent(self.client.appKey!).appendingPathComponent("files")
                                    if !fileManager.fileExists(atPath: baseFolderURL.path) {
                                        try fileManager.createDirectory(at: baseFolderURL, withIntermediateDirectories: true, attributes: nil)
                                    }
                                    let toURL = baseFolderURL.appendingPathComponent(entityId)
                                    if fileManager.fileExists(atPath: toURL.path) {
                                        do {
                                            try fileManager.removeItem(atPath: toURL.path)
                                        }
                                    }
                                    try fileManager.moveItem(at: url, to: toURL)
                                    
                                    if let cache = self.cache {
                                        cache.save(file) {
                                            file.path = NSString(string: toURL.path).abbreviatingWithTildeInPath
                                            file.etag = response.etag
                                        }
                                    }
                                    
                                    fulfill(toURL)
                                } catch let error {
                                    reject(error)
                                }
                            } else {
                                reject(Error.invalidResponse(httpResponse: response.httpResponse, data: nil))
                            }
                        }
                    } else {
                        fulfill(url)
                    }
                } else {
                    reject(buildError(nil, response, error, self.client))
                }
            }
        }
        return (request: downloadTaskRequest, promise: promise)
    }
    
    @discardableResult
    fileprivate func downloadFileData(_ file: FileType, downloadURL: URL) -> (request: URLSessionTaskRequest, promise: Promise<Data>) {
        let downloadTaskRequest = URLSessionTaskRequest(client: client, url: downloadURL)
        let promise = downloadTaskRequest.downloadTaskWithURL(file).then { arg -> Promise<Data> in
            let (data, _) = arg
            return Promise<Data> { fulfill, reject in
                fulfill(data)
            }
        }
        return (request: downloadTaskRequest, promise: promise)
    }
    
    /// Returns the cached file, if exists.
    open func cachedFile(_ entityId: String) -> FileType? {
        return cache?.get(entityId)
    }
    
    /// Returns the cached file, if exists.
    open func cachedFile(_ file: FileType) -> FileType? {
        let entityId = crashIfInvalid(file: file)
        return cachedFile(entityId)
    }
    
    @discardableResult
    fileprivate func crashIfInvalid(file: FileType) -> String {
        guard let fileId = file.fileId else {
            fatalError("fileId is required")
        }
        return fileId
    }
    
    /// Downloads a file using the `downloadURL` of the `File` instance.
    @discardableResult
    open func download(_ file: FileType, storeType: StoreType = .cache, ttl: TTL? = nil, completionHandler: FilePathCompletionHandler? = nil) -> Request {
        return download(
            file,
            storeType: storeType,
            ttl: ttl
        ) { (result: Result<(FileType, URL), Swift.Error>) in
            switch result {
            case .success(let file, let url):
                completionHandler?(file, url, nil)
            case .failure(let error):
                completionHandler?(nil, nil, error)
            }
        }
    }
    
    /// Downloads a file using the `downloadURL` of the `File` instance.
    @discardableResult
    open func download(_ file: FileType, storeType: StoreType = .cache, ttl: TTL? = nil, completionHandler: ((Result<(FileType, URL), Swift.Error>) -> Void)? = nil) -> Request {
        crashIfInvalid(file: file)
        
        if storeType == .sync || storeType == .cache,
            let entityId = file.fileId,
            let cachedFile = cachedFile(entityId),
            let pathURL = file.pathURL
        {
            DispatchQueue.main.async {
                completionHandler?(.success((cachedFile, pathURL)))
            }
        }
        
        if storeType == .cache || storeType == .network {
            let multiRequest = MultiRequest()
            Promise<(FileType, URL)> { fulfill, reject in
                if let downloadURL = file.downloadURL, file.publicAccessible || (file.expiresAt != nil && file.expiresAt!.timeIntervalSinceNow > 0) {
                    fulfill((file, downloadURL))
                } else {
                    let (request, promise) = getFileMetadata(file, ttl: ttl)
                    multiRequest += request
                    promise.then { (file) -> Void in
                        if let downloadURL = file.downloadURL {
                            fulfill((file, downloadURL))
                        } else {
                            throw Error.invalidResponse(httpResponse: nil, data: nil)
                        }
                    }.catch { error in
                        reject(error)
                    }
                }
            }.then { arg -> Promise<(FileType, URL)> in
                let (file, downloadURL) = arg
                let (request, promise) = self.downloadFileURL(file, storeType: storeType, downloadURL: downloadURL)
                multiRequest += (request, true)
                return promise.then { localUrl in
                    return Promise<(FileType, URL)> { fulfill, reject in
                        fulfill((file, localUrl))
                    }
                }
            }.then { arg -> Void in
                let (file, localUrl) = arg
                completionHandler?(.success((file, localUrl)))
            }.catch { error in
                completionHandler?(.failure(error))
            }
            return multiRequest
        } else {
            return LocalRequest()
        }
    }
    
    /// Downloads a file using the `downloadURL` of the `File` instance.
    @discardableResult
    open func download(_ file: FileType, ttl: TTL? = nil, completionHandler: FileDataCompletionHandler? = nil) -> Request {
        return download(
            file,
            ttl: ttl
        ) { (result: Result<(FileType, Data), Swift.Error>) in
            switch result {
            case .success(let file, let data):
                completionHandler?(file, data, nil)
            case .failure(let error):
                completionHandler?(nil, nil, error)
            }
        }
    }
    
    private enum DownloadStage {
        
        case downloadURL(URL)
        case data(Data)
        
    }
    
    /// Downloads a file using the `downloadURL` of the `File` instance.
    @discardableResult
    open func download(_ file: FileType, ttl: TTL? = nil, completionHandler: ((Result<(FileType, Data), Swift.Error>) -> Void)? = nil) -> Request {
        crashIfInvalid(file: file)
        
        let multiRequest = MultiRequest()
        Promise<(FileType, DownloadStage)> { fulfill, reject in
            if let entityId = file.fileId, let cachedFile = cachedFile(entityId), let path = file.path, let data = try? Data(contentsOf: URL(fileURLWithPath: path)) {
                fulfill((cachedFile, .data(data)))
                return
            }
            
            if let downloadURL = file.downloadURL, file.publicAccessible || (file.expiresAt != nil && file.expiresAt!.timeIntervalSinceNow > 0) {
                fulfill((file, .downloadURL(downloadURL)))
            } else {
                let (request, promise) = getFileMetadata(file, ttl: ttl)
                multiRequest += request
                promise.then { file -> Void in
                    if let downloadURL = file.downloadURL, file.publicAccessible || (file.expiresAt != nil && file.expiresAt!.timeIntervalSinceNow > 0) {
                        fulfill((file, .downloadURL(downloadURL)))
                    } else {
                        throw Error.invalidResponse(httpResponse: nil, data: nil)
                    }
                }.catch { error in
                    reject(error)
                }
            }
        }.then { arg -> Promise<Data> in
            let (file, downloadStage) = arg
            switch downloadStage {
            case .downloadURL(let downloadURL):
                let (request, promise) = self.downloadFileData(file, downloadURL: downloadURL)
                multiRequest += (request, addProgress: true)
                return promise
            case .data(let data):
                return Promise<Data> { fulfill, reject in
                    fulfill(data)
                }
            }
        }.then { data in
            completionHandler?(.success((file, data)))
        }.catch { error in
            completionHandler?(.failure(error))
        }
        return multiRequest
    }
    
    /// Deletes a file instance in the backend.
    @discardableResult
    open func remove(_ file: FileType, completionHandler: UIntCompletionHandler? = nil) -> Request {
        return remove(file) { (result: Result<UInt, Swift.Error>) in
            switch result {
            case .success(let count):
                completionHandler?(count, nil)
            case .failure(let error):
                completionHandler?(nil, error)
            }
        }
    }
    
    /// Deletes a file instance in the backend.
    @discardableResult
    open func remove(_ file: FileType, completionHandler: ((Result<UInt, Swift.Error>) -> Void)? = nil) -> Request {
        let request = client.networkRequestFactory.buildBlobDeleteFile(file)
        Promise<UInt> { fulfill, reject in
            request.execute({ (data, response, error) -> Void in
                if let response = response, response.isOK,
                    let json = self.client.responseParser.parse(data),
                    let count = json["count"] as? UInt
                {
                    if let cache = self.cache {
                        cache.remove(file)
                    }
                    
                    fulfill(count)
                } else {
                    reject(buildError(data, response, error, self.client))
                }
            })
        }.then { count in
            completionHandler?(.success(count))
        }.catch { error in
            completionHandler?(.failure(error))
        }
        return request
    }
    
    /// Gets a list of files that matches with the query passed by parameter.
    @discardableResult
    open func find(_ query: Query = Query(), ttl: TTL? = nil, completionHandler: FileArrayCompletionHandler? = nil) -> Request {
        return find(
            query,
            ttl: ttl
        ) { (result: Result<[FileType], Swift.Error>) in
            switch result {
            case .success(let files):
                completionHandler?(files, nil)
            case .failure(let error):
                completionHandler?(nil, error)
            }
        }
    }
    
    /// Gets a list of files that matches with the query passed by parameter.
    @discardableResult
    open func find(_ query: Query = Query(), ttl: TTL? = nil, completionHandler: ((Result<[FileType], Swift.Error>) -> Void)? = nil) -> Request {
        let request = client.networkRequestFactory.buildBlobQueryFile(query, ttl: ttl)
        Promise<[FileType]> { fulfill, reject in
            request.execute { (data, response, error) -> Void in
                if let response = response,
                    response.isOK,
                    let jsonArray = self.client.responseParser.parseArray(data)
                {
                    let files = [FileType](JSONArray: jsonArray)
                    fulfill(files)
                } else {
                    reject(buildError(data, response, error, self.client))
                }
            }
        }.then { files in
            completionHandler?(.success(files))
        }.catch { error in
            completionHandler?(.failure(error))
        }
        return request
    }
    
    /**
     Clear cached files from local storage.
     */
    open func clearCache() {
        client.cacheManager.clearAll()
    }
    
}
