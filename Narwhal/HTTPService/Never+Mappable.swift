//
//  Never+Mappable.swift
//  Narwhal
//
//  Created by Max Adamyan on 3/1/19.
//

import Foundation
import ObjectMapper

extension Never: Mappable {
    public init?(map: Map) { return nil }
    public mutating func mapping(map: Map) { }
}
