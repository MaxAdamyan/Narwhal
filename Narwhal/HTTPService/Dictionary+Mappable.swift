//
//  Dictionary+Mappable.swift
//  Narwhal
//
//  Created by Max Adamyan on 3/4/19.
//

import Foundation
import ObjectMapper

extension Dictionary: BaseMappable where Key == String, Value == Any {
    public mutating func mapping(map: Map) {
        self = map.JSON
    }
}

extension Dictionary: Mappable where Key == String, Value == Any {
    public init?(map: Map) {
        self = map.JSON
    }
}
