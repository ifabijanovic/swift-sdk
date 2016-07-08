//
//  JsonResponseParser.swift
//  Kinvey
//
//  Created by Victor Barros on 2015-12-09.
//  Copyright © 2015 Kinvey. All rights reserved.
//

import Foundation

class JsonResponseParser: ResponseParser {
    
    let client: Client
    
    init(client: Client) {
        self.client = client
    }
    
    func parseArray(data: NSData?) -> [JsonDictionary]? {
        if let data = data where data.length > 0 {
            let result = try? NSJSONSerialization.JSONObjectWithData(data, options: []) as! [JsonDictionary]
            return result
        }
        return nil
    }
    
    func parse(data: NSData?) -> JsonDictionary? {
        if let data = data where data.length > 0,
            let result = try? NSJSONSerialization.JSONObjectWithData(data, options: []) as? JsonDictionary,
            let json = result
        {
            return json
        }
        return nil
    }
    
    func parseUser(data: NSData?) -> User? {
        if let data = data where data.length > 0,
            let result = try? NSJSONSerialization.JSONObjectWithData(data, options: []) as? JsonDictionary,
            let json = result
        {
            let map = Map(mappingType: .FromJSON, JSONDictionary: json)
            let user = client.userType.init(map)
            user?.mapping(map)
            return user
        }
        return nil
    }

}
